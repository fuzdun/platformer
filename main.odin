package main

import "core:sort"
import "core:encoding/xml/example"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:flags"
import "core:math"
import vmem "core:mem/virtual"
import glm "core:math/linalg/glsl"
import str "core:strings"
import rnd "core:math/rand"
import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"
import gl "vendor:OpenGL"
import ft "shared:freetype"
import imgui "shared:odin-imgui"
import imsdl "shared:odin-imgui/imgui_impl_sdl2"
import imgl "shared:odin-imgui/imgui_impl_opengl3"

MAX_LEVEL_GEOMETRY_COUNT :: 2000

EDIT :: #config(EDIT, false)
PERF_TEST :: #config(PERF_TEST, false)
MOVE :: #config(MOVE, false)
GENERATE :: #config(GENERATE, false)

WIDTH :: 1920.0
HEIGHT :: 1080.0
FULLSCREEN :: true
TARGET_FRAME_RATE :: 60.0
FIXED_DELTA_TIME :: f32(1.0 / TARGET_FRAME_RATE)
FORCE_EXTERNAL_MONITOR :: false

TITLE :: "Durian"

SEED := rnd.float32() * 1000

quit_app := false

main :: proc () {


    // ####################################################
    // DEBUG MEMORY ALLOCATOR
    // #####################################################

    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
        defer {
            if len(track.allocation_map) > 0{
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map)) 
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v vytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }


    // #####################################################
    // INIT ARENA ALLOCATORS
    // #####################################################

    perm_arena: vmem.Arena
    arena_err := vmem.arena_init_growing(&perm_arena); ensure(arena_err == nil)
    perm_arena_alloc := vmem.arena_allocator(&perm_arena)


    // #####################################################
    // SET LEVEL TO LOAD 
    // #####################################################

    level_to_load := "levels/test_level.bin"
    
    if len(os.args) == 3 {
        if os.args[1] == "chunk" {
            level_to_load = str.concatenate({"chunks/chunk_", os.args[2], ".bin" }, perm_arena_alloc)
       }
    }
    if len(os.args) == 2 {
        level_to_load = str.concatenate({"levels/", os.args[1], ".bin"}, perm_arena_alloc)
    }


    // #####################################################
    // INIT SDL WINDOW
    // #####################################################

    controller, window := init_sdl()
    defer SDL.DestroyWindow(window)


    // #####################################################
    // INIT OPENGL
    // #####################################################

    init_opengl(window)


    // #####################################################
    // ALLOCATE STATE STRUCTS
    // #####################################################

    lgs:   Level_Geometry_State;
    is:    Input_State;
    cs:    Camera_State;
    es:    Editor_State;
    phs:   Physics_State;
    shs:   Shader_State;
    rs:    Render_State;
    bs:    Buffer_State;
    pls:   Player_State;
    sr:    Shape_Resources;
    szs:   Slide_Zone_State;
    ptcls: Particle_State;
    gs:    Game_State;

    init_player_state(&pls, perm_arena_alloc)
    init_render_state(&rs, context.allocator); defer free_render_state(rs)
    init_camera_state(&cs)
    init_editor_state(&es, level_to_load)
    init_slide_zone_state(&szs, context.allocator); defer free_slide_zone_state(szs)
    init_game_state(&gs)

    // player icosphere mesh
    // -------------------------------------------
    add_player_sphere_data(&sr.player_vertices, &sr.player_fill_indices, &sr.player_outline_indices, perm_arena_alloc)

    // player spin particles
    // -------------------------------------------
    particle_buffer_init(&ptcls.player_burst_particles, context.allocator)
    defer particle_buffer_free(ptcls.player_burst_particles)


    // #####################################################
    // LOAD BLENDER RESOURCES 
    // #####################################################

    for shape in SHAPE {
        if ok := load_glb_model(shape, &sr, &phs, perm_arena_alloc); ok {
            fmt.println("loaded", shape) 
        }
    }

    for &v in sr.level_geometry[.SPIN_TRAIL].vertices {
        v.pos.yz *= 10.0
        v.pos.x *= .5
    }


    // #####################################################
    // LOAD LEVEL GEOMETRY
    // #####################################################

    // load from level file
    // -------------------------------------------
    loaded_level_geometry: []Level_Geometry

    if GENERATE {
        loaded_level_geometry = generate_level(context.temp_allocator)
    } else {
        loaded_level_geometry = load_level_geometry(level_to_load, context.temp_allocator)
    }

    num_entities := len(loaded_level_geometry) 

    // convert loaded gemoetry to SOA ------
    lgs = make(Level_Geometry_State, len(loaded_level_geometry), context.allocator); defer delete_soa(lgs)
    for lg, idx in loaded_level_geometry {
        append(&lgs, lg)
    }


    // #####################################################
    // LOAD SLIDE ZONES
    // #####################################################

    for lg, lg_idx in lgs {
        if .Slide_Zone in lg.attributes {
            sz: Obb
            sz.id = lg_idx
            rot_mat := glm.mat4FromQuat(lg.transform.rotation)
            x := rot_mat * [4]f32{1, 0, 0, 0}
            y := rot_mat * [4]f32{0, 1, 0, 0}
            z := rot_mat * [4]f32{0, 0, 1, 0}
            sz.axes = {x.xyz, y.xyz, z.xyz}
            sz.dim = lg.transform.scale 
            sz.center = lg.transform.position
            append(&szs.entities, sz)
        }
    }

    // #####################################################
    // INITIALIZE EDITOR ATTRIBUTES 
    // #####################################################

    for attribute in lgs[es.selected_entity].attributes {
        es.displayed_attributes[attribute] = true
    }


    // #####################################################
    // COMPILE SHADERS 
    // #####################################################

    init_shaders(&shs, perm_arena_alloc)


    // #####################################################
    // INIT OPENGL TEXT RENDERING
    // #####################################################

    init_opengl_text_rendering(&bs, perm_arena_alloc)


    // #####################################################
    // INIT OPENGL MESH RENDERING
    // #####################################################

    init_opengl_mesh_rendering(&bs, ptcls, &sr, perm_arena_alloc)


    // #####################################################
    // INIT IMGUI
    // #####################################################

    when ODIN_OS != .Windows {
        if EDIT {
            imgui.create_context()
            imgui.style_colors_dark()
            io := imgui.get_io()
            io.config_flags |= {imgui.Config_Flag.Docking_Enable}
            imsdl.init_for_open_gl(window, gl_context)
            imgl.init()
        }
    }
    

    // #####################################################
    // FRAME LOOP 
    // #####################################################

    clocks_per_second := i64(SDL.GetPerformanceFrequency())
    target_frame_clocks := clocks_per_second / TARGET_FRAME_RATE
    max_deviation := clocks_per_second / 5000

    snap_hz: i64 = 60
    current_display_mode: SDL.DisplayMode
    if SDL.GetCurrentDisplayMode(0, &current_display_mode) == 0 {
        snap_hz = i64(current_display_mode.refresh_rate)
    }
    snap_hz = i64(clocks_per_second) / snap_hz
    snap_vals : [8]i64 = { snap_hz, snap_hz * 2, snap_hz * 3, snap_hz * 4, snap_hz * 5, snap_hz * 6, snap_hz * 7, snap_hz * 8 }
    
    frame_time_buffer : RingBuffer(4, i64)
    ring_buffer_init(&frame_time_buffer, target_frame_clocks, perm_arena_alloc)

    current_time, previous_time, delta_time, averager_res, accumulator : i64
    previous_time = i64(SDL.GetPerformanceCounter())

    resync := true
    quit_handler :: proc () { quit_app = true }

    ubo_size: i32 = 0
    gl.GetIntegerv(gl.MAX_UNIFORM_BLOCK_SIZE, &ubo_size)

    for !quit_app {
        if quit_app do break

        elapsed_time := f64(SDL.GetTicks())

        current_time = i64(SDL.GetPerformanceCounter())
        delta_time = current_time - previous_time
        previous_time = current_time

        if delta_time > target_frame_clocks * 8 {
            delta_time = target_frame_clocks
        }

        for val in snap_vals {
            if abs(delta_time - val) < max_deviation {
                delta_time = val
                break
            }
        }

        ring_buffer_push(&frame_time_buffer, delta_time)
        delta_time = ring_buffer_average(frame_time_buffer)
        averager_res += delta_time % 4 
        delta_time += averager_res / 4
        averager_res %= 4

        accumulator += delta_time

        if accumulator > target_frame_clocks * 8 {
            resync = true
        }

        if(resync) {
            accumulator = 0;
            delta_time = target_frame_clocks;
            resync = false;
        }

        // handle input
        // -------------------------------------------
        process_input(&is, quit_handler)

        for accumulator >= target_frame_clocks {

            // fixed update
            // -------------------------------------------
            if EDIT {
                editor_update(&lgs, sr, &es, &cs, is, &rs, &phs, FIXED_DELTA_TIME)
            } else {
                gameplay_update(&lgs, is, &pls, &phs, &rs, &ptcls, bs, &cs, &szs, &gs, f32(elapsed_time), FIXED_DELTA_TIME * gs.time_mult)
            }
            accumulator -= target_frame_clocks 
        }

        interpolated_time := f64(accumulator) / f64(target_frame_clocks)

        // render
        // -------------------------------------------
        draw(lgs[:], sr, pls, &rs, &ptcls, bs, &shs, &phs, &cs, is, es, szs, gs, elapsed_time, interpolated_time, FIXED_DELTA_TIME * gs.time_mult)
        when ODIN_OS != .Windows {
            if EDIT {
                update_imgui(&es, &dynamic_lgs)
            }
        }
        SDL.GL_SwapWindow(window)
        free_all(context.temp_allocator)
    }

    when ODIN_OS != .Windows {
        if EDIT {
            imgl.shutdown()
            imsdl.shutdown()
            imgui.destroy_context()
        }
    }
    ft.done_face(bs.face)
    ft.done_free_type(bs.ft_lib)
    vmem.arena_destroy(&perm_arena)
}

