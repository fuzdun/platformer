package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"

WIDTH :: 1000 
HEIGHT :: 1000
TITLE :: "platformer"

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

    ecs_init(); defer ecs_free()

    wall := add_entity()
    add_position(wall, {0, 0, 0})
    add_velocity(wall, {0, 1, 0})
    apply_velocities()


    init_render_buffers(); defer free_render_buffers()
    init_draw()
    load_level()
    frame_loop(window)
}
