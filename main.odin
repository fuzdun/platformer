package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"

WIDTH :: 1000 
HEIGHT :: 1000
TITLE :: "platformer"

GameState :: struct {
    ecs: ECSState,
}

gamestate_init :: proc(gs: ^GameState) {
    ecs_init(&gs.ecs)
}

gamestate_free :: proc(gs: ^GameState) {
    ecs_free(&gs.ecs)
}

main :: proc () {
    window := SDL.CreateWindow(TITLE, SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WIDTH, HEIGHT, {.OPENGL})
    if window == nil {
        fmt.eprintln("Failed to create window")
    }
    defer SDL.DestroyWindow(window)
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(3, 3, SDL.gl_set_proc_address)
    SDL.GL_SetSwapInterval(1)

    gs : GameState
    gamestate_init(&gs); defer gamestate_free(&gs)

    ss: ShaderState
    shader_state_init(&ss); defer shader_state_free(&ss)

    rs: RenderState
    init_render_buffers(&rs); defer free_render_buffers(&rs)

    init_draw(&rs, &ss)
    load_level(&rs, ss)

    using gs
    wall := add_entity(&ecs)
    add_position(&ecs, wall, {0, 0, 0})
    add_velocity(&ecs, wall, {0, 1, 0})
    fmt.println(ecs.comp_data.positions)

    frame_loop(window, &gs, &rs, &ss)
}
