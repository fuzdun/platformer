package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import "core:mem"
import "core:os"

//WIDTH :: 1920.0
//HEIGHT :: 1080.0
WIDTH :: 720
HEIGHT :: 720
TITLE :: "platformer"

EDIT :: #config(EDIT, false)

Game_State :: struct {
    player_geometry: Shape_Data,
    level_resources: map[string]Shape_Data,
    level_geometry: Level_Geometry_State,
    player_state: Player_State,
    input_state: Input_State,
    camera_state: Camera_State,
    editor_state: Editor_State,
    dirty_entities: [dynamic]int
}

gamestate_init :: proc(gs: ^Game_State) {
    gs.level_resources = make(map[string]Shape_Data)
    gs.level_geometry = make(Level_Geometry_State)
    gs.player_state.trail = make([dynamic][3]f32)
    gs.dirty_entities = make([dynamic]int)
    //append(&gs.dirty_entities, 0, 1, 2, 3)
    resize(&gs.player_state.trail, TRAIL_SIZE)
}

gamestate_free :: proc(gs: ^Game_State) {
    delete_soa(gs.level_geometry)
    delete(gs.dirty_entities)
    for lg in gs.level_geometry {
        //delete(lg.shape)
        //delete(lg.collider)
    }
    delete(gs.player_state.trail)
    delete(gs.player_geometry.vertices)
    delete(gs.player_geometry.indices)
    for _, sd in gs.level_resources {
        delete(sd.indices) 
        delete(sd.vertices)
    }
    delete(gs.level_resources)
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
    if (SDL.Init({.VIDEO, .GAMECONTROLLER}) < 0) {
        fmt.println("SDL could not initialize")
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

    // hook up OpenGL
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(4, 6, SDL.gl_set_proc_address)

    // allocate / defer deallocate state structs
    gs : Game_State
    gamestate_init(&gs); defer gamestate_free(&gs)
    gs.player_state.position.z = 60
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

    load_level_geometry(&gs, &ps, "test_level")

    init_level_render_data(&gs, &ss, &rs)
    init_player_render_data(&gs, &ss, &rs)
    bind_vertices(&rs)
    

    // start frame loop
    SDL.GL_SetSwapInterval(1)
    frame_loop(window, &gs, &rs, &ss, &ps)
}

