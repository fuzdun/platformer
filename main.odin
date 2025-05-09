package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import "core:mem"
import "core:os"

// WIDTH :: 1920.0
// HEIGHT :: 1080.0
// FULLSCREEN :: true
WIDTH :: 900
HEIGHT :: 900
FULLSCREEN :: false

TITLE :: "platformer"

EDIT :: #config(EDIT, false)

INIT_PLAYER_POS :: [3]f32 { 0, 0, 0 }

Game_State :: struct {
    player_geometry: Shape_Data,
    level_resources: [SHAPES]Shape_Data,
    level_geometry: Level_Geometry_State,
    player_state: Player_State,
    input_state: Input_State,
    camera_state: Camera_State,
    editor_state: Editor_State,
    dirty_entities: [dynamic]int,
    time_mult: f32
}

gamestate_init :: proc(gs: ^Game_State) {
    gs.level_geometry = make(Level_Geometry_State)

    // gs.player_state.trail = make([dynamic][3]f32)
    ring_buffer_init(&gs.player_state.trail, [3]f32{0, 0, 0})

    gs.player_state.state = .IN_AIR
    gs.player_state.position = INIT_PLAYER_POS
    gs.player_state.can_press_dash = true
    gs.player_state.can_press_jump = false
    gs.camera_state.position = {10, 60, 300}
    gs.dirty_entities = make([dynamic]int)
    gs.editor_state.y_rot = -.25
    gs.editor_state.zoom = 200
    gs.editor_state.connections = make([dynamic]Connection)
    // for &registry in gs.editor_state.ssbo_registry {
    //     registry = make([dynamic]int)
    // }
    // resize(&gs.player_state.trail, TRAIL_SIZE)
    gs.time_mult = 1
}

gamestate_free :: proc(gs: ^Game_State) {
    delete_soa(gs.level_geometry)
    delete(gs.dirty_entities)
    delete(gs.editor_state.connections)
    // delete(gs.player_state.trail)
    delete(gs.player_geometry.vertices)
    delete(gs.player_geometry.indices)
    for sd in gs.level_resources {
        delete(sd.indices) 
        delete(sd.vertices)
    }
    // for registry in gs.editor_state.ssbo_registry {
    //     delete(registry)
    // }
}

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

    // create SDL window
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
    gs : Game_State
    gamestate_init(&gs); defer gamestate_free(&gs)
    gs.player_state.ground_x = {1, 0, 0}
    gs.player_state.ground_z = {0, 0, -1}

    ps: Physics_State
    init_physics_state(&ps); defer free_physics_state(&ps)

    load_geometry_data(&gs, &ps)

    ss: ShaderState
    shader_state_init(&ss); defer shader_state_free(&ss)

    rs: Render_State
    init_render_buffers(&gs, &rs); defer free_render_buffers(&rs)


    // initialize OpenGL state
    if !init_draw(&rs, &ss) {
        fmt.eprintln("init draw failed")
        return
    }

    load_level_geometry(&gs, &ps, &rs, "test_level")
    init_level_render_data(&gs, &rs)

    // start frame loop
    frame_loop(window, &gs, &rs, &ss, &ps)
}

