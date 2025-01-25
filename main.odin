package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:mem"

WIDTH :: 1920.0
HEIGHT :: 1080.0
TITLE :: "platformer"

GameState :: struct {
    ecs: ECS,
    // player state
    // ui state
    // game mode
    // etc
}

gamestate_init :: proc(gs: ^GameState) {
    ecs_init(&gs.ecs)
    // init player state
    // etc
}

gamestate_free :: proc(gs: ^GameState) {
    ecs_free(&gs.ecs)
    // free player state
    // etc
}

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
    window := SDL.CreateWindow(TITLE, SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WIDTH, HEIGHT, {.OPENGL})
    if window == nil {
        fmt.eprintln("Failed to create window")
    }
    defer SDL.DestroyWindow(window)

    // hook up OpenGL
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(3, 3, SDL.gl_set_proc_address)
    SDL.GL_SetSwapInterval(1)

    // allocate / defer deallocate state structs
    gs : GameState
    gamestate_init(&gs); defer gamestate_free(&gs)

    ss: ShaderState
    shader_state_init(&ss); defer shader_state_free(&ss)

    rs: RenderState
    init_render_buffers(&rs); defer free_render_buffers(&rs)

    // initialize OpenGL state
    init_draw(&rs, &ss)

    // load test geometry
    load_random_shapes(&gs, 500)
    load_test_floor(&gs, 10, 10)

    // start frame loop
    frame_loop(window, &gs, &rs, &ss)
}

