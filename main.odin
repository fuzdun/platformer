package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:mem"

WIDTH :: 1920.0
HEIGHT :: 1080.0
//WIDTH :: 720
//HEIGHT :: 720
TITLE :: "platformer"

Game_State :: struct {
    level_resources: map[string]Shape_Data,
    level_geometry: #soa[dynamic]Level_Geometry,
    player_state: Player_State,
    input_state: Input_State,
    camera_state: Camera_State
}

gamestate_init :: proc(gs: ^Game_State) {
    gs.level_resources = make(map[string]Shape_Data)
    gs.level_geometry = make(Level_Geometry_State)
    gs.player_state.trail = make([dynamic][3]f32)
    resize(&gs.player_state.trail, TRAIL_SIZE)
}

gamestate_free :: proc(gs: ^Game_State) {
    delete(gs.level_resources)
    delete(gs.level_geometry)
    delete(gs.player_state.trail)
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
    gl.load_up_to(3, 3, SDL.gl_set_proc_address)

    // allocate / defer deallocate state structs
    gs : Game_State
    gamestate_init(&gs); defer gamestate_free(&gs)
    gs.player_state.position.z = 60
    gs.player_state.ground_x = {1, 0, 0}
    gs.player_state.ground_z = {0, 0, -1}

    load_geometry_data(&gs)
    //fmt.println(gs.level_resources["cube"])

    ss: ShaderState
    shader_state_init(&ss); defer shader_state_free(&ss)

    rs: RenderState
    init_render_buffers(&rs); defer free_render_buffers(&rs)

    ps: Physics_State
    init_physics_state(&ps); defer free_physics_state(&ps)

    // initialize OpenGL state
    init_draw(&rs, &ss)
    SDL.GL_SetSwapInterval(1)

    // load test geometry
    //load_random_shapes(&gs, 200)
    load_test_floor(&gs, 1000, 1000)
    load_physics_test_box(&gs, 30, 30, 30, 400)
    

    // start frame loop
    //load_blender_model("cube")
    frame_loop(window, &gs, &rs, &ss, &ps)
}

