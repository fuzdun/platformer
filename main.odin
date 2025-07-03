package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import "core:mem"
import "core:os"
import glm "core:math/linalg/glsl"
import str "core:strings"
import ft "shared:freetype"
import st "state"
import enm "state/enums"

WIDTH :: 1920.0
HEIGHT :: 1080.0
FULLSCREEN :: true
TARGET_FRAME_RATE :: 240.0
FIXED_DELTA_TIME :: f32(1.0 / TARGET_FRAME_RATE)
// WIDTH :: 900
// HEIGHT :: 900
// FULLSCREEN :: false

TITLE :: "platformer"

EDIT :: #config(EDIT, false)
PERF_TEST :: #config(PERF_TEST, false)

INIT_PLAYER_POS :: [3]f32 { 0, 0, 0 }

controller : ^SDL.GameController

@(private="file")
quit_app := false

main :: proc () {
    // debug mem leak detector
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

    //create SDL window
    if SDL.Init({.VIDEO, .GAMECONTROLLER}) < 0 {
        fmt.println("SDL could not initialize")
    }
    SDL.GL_SetSwapInterval(1)

    if TTF.Init() == -1 {
        fmt.eprintln("failed to initialize TTF:", TTF.GetError())
    }

    for i in 0..<SDL.NumJoysticks() {
        if (SDL.IsGameController(i)) {
            controller = SDL.GameControllerOpen(i)
        }
    }
    window := SDL.CreateWindow(TITLE, SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WIDTH, HEIGHT, {.OPENGL})
    if window == nil {
        fmt.eprintln("Failed to create window")
    }
    defer SDL.DestroyWindow(window)
    if FULLSCREEN {
        SDL.SetWindowFullscreen(window, SDL.WINDOW_FULLSCREEN)
    }

    // hook up OpenGL
    SDL.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
    SDL.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 6)
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(4, 6, SDL.gl_set_proc_address)

    // allocate / defer deallocate state structs
    gs:  st.Game_State;      defer st.free_gamestate(&gs)
    phs: st.Physics_State;   defer st.free_physics_state(&phs)
    shs: Shader_State;       defer free_shader_state(&shs)
    rs:  st.Render_State;    defer st.free_render_state(&rs)
    pls: st.Player_State;    defer st.free_player_state(&pls)
    lrs: st.Level_Resources; defer st.free_level_resources(&lrs)

    // init game state
    gs.level_geometry = make(st.Level_Geometry_State)
    gs.camera_state.position = {10, 60, 300}
    gs.dirty_entities = make([dynamic]int)
    gs.editor_state.y_rot = -.25
    gs.editor_state.zoom = 400
    gs.editor_state.connections = make([dynamic]st.Connection)
    gs.time_mult = 1

    // init physics state
    phs.collisions = make([dynamic]st.Collision)
    phs.debug_render_queue.vertices = make([dynamic]st.Vertex)
    phs.static_collider_vertices = make([dynamic][3]f32)
    for pn in enm.ProgramName {
        phs.debug_render_queue.indices[pn] = make([dynamic]u16)
    }

    // init shaders state
    shs.active_programs = make(map[enm.ProgramName]ActiveProgram)

    // init render state
    for shader in enm.ProgramName {
        rs.shader_render_queues[shader] = make([dynamic]gl.DrawElementsIndirectCommand)
    }
    rs.static_transforms = make([dynamic]glm.mat4)
    rs.z_widths = make([dynamic]f32)
    rs.player_particle_poss = make([dynamic]glm.vec3)
    add_player_sphere_data(&rs)
    {
        vertices := make([dynamic]st.Vertex); defer delete(vertices)
        indices := make([dynamic]u32); defer delete(indices)
        for shape in enm.SHAPE {
            rs.vertex_offsets[int(shape)] = u32(len(vertices))
            rs.index_offsets[int(shape)] = u32(len(indices))
        }
        rs.player_vertex_offset = u32(len(vertices))
        rs.player_index_offset = u32(len(indices))
    }

    // init player state
    pls.state = .IN_AIR
    pls.position = INIT_PLAYER_POS
    pls.can_press_dash = true
    pls.can_press_jump = false
    pls.ground_x = {1, 0, 0}
    pls.ground_z = {0, 0, -1}
    st.ring_buffer_init(&pls.trail, [3]f32{0, 0, 0})

    // load blender meshes
    for shape in enm.SHAPE {
        if ok := load_blender_model(shape, &lrs, &phs); ok {
            fmt.println("loaded", shape) 
        }
    }

    // initialize OpenGL state
    //if !init_draw(&rs, lrs, &shs) {
    //    fmt.eprintln("init draw failed")
    //    return
    //}
    for config, program in PROGRAM_CONFIGS {
        shaders := make([]u32, len(config.pipeline))
        defer delete(shaders)
        for filename, shader_i in config.pipeline {
            id, ok := shader_program_from_file(filename, config.shader_types[shader_i])
            if !ok {
                //return false
            }
            shaders[shader_i] = id
        }

        program_id, program_ok := gl.create_and_link_program(shaders)
        if !program_ok {
            fmt.eprintln("program link failed:", program)
            //return false
        }
        shs.active_programs[program] = {program_id, config.init_proc, make(map[string]i32)}
        prog := shs.active_programs[program]
        for uniform in config.uniforms {
            cstr_name := str.clone_to_cstring(uniform); defer delete(cstr_name)
            prog.locations[uniform] = gl.GetUniformLocation(program_id, cstr_name)
            shs.active_programs[program] = prog
        }
    }

    //return true
    ft.init_free_type(&rs.ft_lib)
    ft.new_face(rs.ft_lib, "fonts/0xProtoNerdFont-Bold.ttf", 0, &rs.face)
    rs.char_tex_map = make(map[rune]st.Char_Tex)
    ft.set_pixel_sizes(rs.face, 0, 256)
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    for c in 0..<128 {
        if char_load_err := ft.load_char(rs.face, u32(c), {ft.Load_Flag.Render}); char_load_err != nil {
            fmt.eprintln(char_load_err)
        }
        new_tex: u32 
        gl.GenTextures(1, &new_tex)
        gl.BindTexture(gl.TEXTURE_2D, new_tex)
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            i32(rs.face.glyph.bitmap.width),
            i32(rs.face.glyph.bitmap.rows),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            rs.face.glyph.bitmap.buffer
        )
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        ct: st.Char_Tex = {
            id = new_tex,
            size = {i32(rs.face.glyph.bitmap.width), i32(rs.face.glyph.bitmap.rows)},
            bearing = {i32(rs.face.glyph.bitmap_left), i32(rs.face.glyph.bitmap_top)},
            next = u32(rs.face.glyph.advance.x)
        }
        // fmt.println(ct)
        rs.char_tex_map[rune(c)] = ct
    } 

    //if !init_shaders(ss) {
    //    fmt.eprintln("shader init failed")
    //    return false
    //}

    gl.GenBuffers(1, &rs.standard_vbo)
    gl.GenBuffers(1, &rs.standard_ebo)
    gl.GenBuffers(1, &rs.indirect_buffer)
    gl.GenBuffers(1, &rs.transforms_ssbo)
    gl.GenBuffers(1, &rs.z_widths_ssbo)
    gl.GenBuffers(1, &rs.particle_vbo)
    gl.GenBuffers(1, &rs.particle_pos_vbo)
    gl.GenBuffers(1, &rs.background_vbo)
    gl.GenBuffers(1, &rs.text_vbo)
    gl.GenBuffers(1, &rs.editor_lines_vbo)
    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenVertexArrays(1, &rs.particle_vao)
    gl.GenVertexArrays(1, &rs.background_vao)
    gl.GenVertexArrays(1, &rs.lines_vao)
    gl.GenVertexArrays(1, &rs.text_vao)
    gl.GenTextures(1, &rs.dither_tex)

    gl.BindVertexArray(rs.standard_vao)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(st.Vertex), offset_of(st.Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(st.Vertex), offset_of(st.Vertex, b_uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(st.Vertex), offset_of(st.Vertex, normal))

    gl.BindVertexArray(rs.particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(st.Quad_Vertex), offset_of(st.Quad_Vertex, position))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(st.Quad_Vertex), offset_of(st.Quad_Vertex, uv))
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, false, 0, 0)
    gl.VertexAttribDivisor(0, 0)
    gl.VertexAttribDivisor(1, 0)
    gl.VertexAttribDivisor(2, 1)

    bv := BACKGROUND_VERTICES
    gl.BindVertexArray(rs.background_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.background_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(bv[0]) * len(bv), &bv[0], gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(st.Quad_Vertex), offset_of(st.Quad_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(st.Quad_Vertex), offset_of(st.Quad_Vertex, uv))

    gl.BindVertexArray(rs.text_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.text_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(st.Quad_Vertex4) * 4, nil, gl.DYNAMIC_DRAW);
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(st.Quad_Vertex4), offset_of(st.Quad_Vertex4, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(st.Quad_Vertex4), offset_of(st.Quad_Vertex4, uv))

    gl.BindVertexArray(rs.lines_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(st.Line_Vertex), offset_of(st.Line_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 1, gl.FLOAT, false, size_of(st.Line_Vertex), offset_of(st.Line_Vertex, t))

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    if dither_bin, read_success := os.read_entire_file("textures/blue_noise_64.png"); read_success {
        defer delete(dither_bin)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0, gl.RGBA, gl.UNSIGNED_BYTE, &dither_bin[0])
    }

    {
        vertices := make([dynamic]st.Vertex); defer delete(vertices)
        indices := make([dynamic]u32); defer delete(indices)
        for shape in enm.SHAPE {
            sd := lrs[shape]
            append(&indices, ..sd.indices)
            append(&vertices, ..sd.vertices)
        }
        append(&indices, ..rs.player_geometry.indices)
        append(&vertices, ..rs.player_geometry.vertices)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW) 
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.LineWidth(5)

    // load level data
    load_level_geometry(&gs, lrs, &phs, &rs, "test_level")

    // start frame loop
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
    
    frame_time_buffer : st.RingBuffer(4, i64)
    st.ring_buffer_init(&frame_time_buffer, target_frame_clocks)

    current_time, previous_time, delta_time, averager_res, accumulator : i64
    previous_time = i64(SDL.GetPerformanceCounter())

    resync := true
    quit_handler :: proc () { quit_app = true }

    for !quit_app {
        if quit_app do break

        elapsed_time := f64(SDL.GetTicks())
        //elapsed_time := f64(SDL.GetTicks()) * 0.1

        current_time = i64(SDL.GetPerformanceCounter())
        delta_time = current_time - previous_time
        previous_time = current_time

        if delta_time > target_frame_clocks * 8 {
            delta_time = target_frame_clocks
        }
        delta_time = max(0, delta_time)

        for val in snap_vals {
            if abs(delta_time - val) < max_deviation {
                delta_time = val
                break
            }
        }

        st.ring_buffer_push(&frame_time_buffer, delta_time)
        delta_time = st.ring_buffer_average(frame_time_buffer)
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

        // Handle input
        process_input(&gs.input_state, quit_handler)

        for accumulator >= target_frame_clocks {
            // Fixed update
            game_update(&gs, lrs, &pls, &phs, &rs, elapsed_time, FIXED_DELTA_TIME * gs.time_mult)
            accumulator -= target_frame_clocks 
        }

        // Render
        gl.Viewport(0, 0, WIDTH, HEIGHT)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        
        update_vertices(&gs, lrs, &rs)
        update_player_particles(&rs, pls, f32(elapsed_time))
        render(&gs, lrs, pls, &rs, &shs, &phs, elapsed_time, f64(accumulator) / f64(target_frame_clocks))

        SDL.GL_SwapWindow(window)
    }
}

