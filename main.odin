package main

import "base:runtime"
import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"

WIDTH :: 1000 
HEIGHT :: 1000
TITLE :: "platformer"

main :: proc () {
    test()
    window := SDL.CreateWindow(TITLE, SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WIDTH, HEIGHT, {.OPENGL})
    if window == nil {
        fmt.eprintln("Failed to create window")
    }
    defer SDL.DestroyWindow(window)
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(3, 3, SDL.gl_set_proc_address)
    SDL.GL_SetSwapInterval(1)

    // add_test_objects()
    init_render_buffers(); defer free_render_buffers()
    init_draw()
    load_level()
    frame_loop(window)
}
