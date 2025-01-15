package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

WIDTH :: 1600 
HEIGHT :: 900
TITLE :: "DummyWindow"

main :: proc () {
    glfw.Init()
    defer glfw.Terminate()
    window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)
    defer glfw.DestroyWindow(window_handle)

    glfw.MakeContextCurrent(window_handle)
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)
    glfw.SetKeyCallback(window_handle, key_callback)

    init_world()
    init_draw()
    add_to_world(.InvertedPyramid)
    main_loop(window_handle)   
}

main_loop :: proc(window_handle: glfw.WindowHandle) {
    TIME_60HZ :: 1.0 / 60.0
    TARGET_FRAME_RATE :: 240.0
    FIXED_DELTA_TIME :: 1.0 / TARGET_FRAME_RATE
    MAX_DEVIATION :: .0002

    accumulator : f64 = 0
    frame_count : i32 = 0

    frame_time_buffer : FrameTimeBuffer
    frame_time_buffer_init(&frame_time_buffer, FIXED_DELTA_TIME)

    snap_vals : [4]f64 = { TIME_60HZ, TIME_60HZ * 2, TIME_60HZ * 3, TIME_60HZ * 4 }

    using glfw
    current_time, last_update_time, delta_time : f64

    for !glfw.WindowShouldClose(window_handle) {
        current_time = GetTime()
        delta_time = current_time - last_update_time
        last_update_time = delta_time

        for val in snap_vals {
            if abs(delta_time - val) < MAX_DEVIATION {
                delta_time = val
            }
        }

        frame_time_buffer_push(&frame_time_buffer, delta_time)
        delta_time = frame_time_buffer_average(&frame_time_buffer)

        accumulator += delta_time

        glfw.PollEvents()
        process_inputs()

        for ; accumulator > FIXED_DELTA_TIME; accumulator -= FIXED_DELTA_TIME {
            frame_count += 1
            move_player(FIXED_DELTA_TIME)
        }

        gl.ClearColor(0.0, 0, 0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        draw_triangles(current_time)
        glfw.SwapBuffers(window_handle)
    }
}