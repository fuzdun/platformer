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

WIDTH :: 1920.0
HEIGHT :: 1080.0
FULLSCREEN :: true
// WIDTH :: 900
// HEIGHT :: 900
// FULLSCREEN :: false

TITLE :: "platformer"

EDIT :: #config(EDIT, false)
PERF_TEST :: #config(PERF_TEST, false)

INIT_PLAYER_POS :: [3]f32 { 0, 0, 0 }

controller : ^SDL.GameController

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
    gs:  Game_State;      defer free_gamestate(&gs)
    phs: Physics_State;   defer free_physics_state(&phs)
    shs: Shader_State;    defer free_shader_state(&shs)
    rs:  Render_State;    defer free_render_state(&rs)
    pls: Player_State;    defer free_player_state(&pls)
    lrs: Level_Resources; defer free_level_resources(&lrs)

    // init game state
    gs.level_geometry = make(Level_Geometry_State)
    gs.camera_state.position = {10, 60, 300}
    gs.dirty_entities = make([dynamic]int)
    gs.editor_state.y_rot = -.25
    gs.editor_state.zoom = 400
    gs.editor_state.connections = make([dynamic]Connection)
    gs.time_mult = 1

    // init physics state
    phs.collisions = make([dynamic]Collision)
    phs.debug_render_queue.vertices = make([dynamic]Vertex)
    phs.static_collider_vertices = make([dynamic][3]f32)
    for pn in ProgramName {
        phs.debug_render_queue.indices[pn] = make([dynamic]u16)
    }

    // init shaders state
    shs.active_programs = make(map[ProgramName]ActiveProgram)

    // init render state
    for shader in ProgramName {
        rs.shader_render_queues[shader] = make([dynamic]gl.DrawElementsIndirectCommand)
    }
    rs.static_transforms = make([dynamic]glm.mat4)
    rs.z_widths = make([dynamic]f32)
    rs.player_particle_poss = make([dynamic]glm.vec3)
    add_player_sphere_data(&rs)
    {
        vertices := make([dynamic]Vertex); defer delete(vertices)
        indices := make([dynamic]u32); defer delete(indices)
        for shape in SHAPE {
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
    ring_buffer_init(&pls.trail, [3]f32{0, 0, 0})

    // load blender meshes
    for shape in SHAPE {
        if ok := load_blender_model(shape, &lrs, &phs); ok {
            fmt.println("loaded", shape) 
        }
    }

    // initialize OpenGL state
    if !init_draw(&rs, lrs, &shs) {
        fmt.eprintln("init draw failed")
        return
    }

    // load level data
    load_level_geometry(&gs, lrs, &phs, &rs, "test_level")

    // start frame loop
    frame_loop(window, &gs, lrs, &pls, &rs, &shs, &phs)
}

