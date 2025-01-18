package main

import SDL "vendor:sdl2"
import gl "vendor:OpenGL"

@(private="file")
quit_app := false

frame_loop :: proc(window: ^SDL.Window) {
    TARGET_FRAME_RATE :: 240.0
    clocks_per_second := SDL.GetPerformanceFrequency()
    FIXED_DELTA_TIME :: 1.0 / TARGET_FRAME_RATE
    target_frame_clocks := clocks_per_second / TARGET_FRAME_RATE

    max_deviation: u64 = clocks_per_second / 5000

    snap_hz: u64 = 60
    current_display_mode: SDL.DisplayMode
    if SDL.GetCurrentDisplayMode(0, &current_display_mode) == 0 {
        snap_hz = u64(current_display_mode.refresh_rate)
    }
    snap_hz = clocks_per_second / snap_hz
    snap_vals : [4]u64 = { snap_hz, snap_hz * 2, snap_hz * 3, snap_hz * 4 }
    
    frame_time_buffer : FrameTimeBuffer
    frame_time_buffer_init(&frame_time_buffer, target_frame_clocks)

    current_time, previous_time, delta_time, averager_res, accumulator : u64
    previous_time = SDL.GetPerformanceCounter()

    quit_handler :: proc () { quit_app = true }
    for !quit_app {
        if quit_app do break

        elapsed_time := f64(SDL.GetTicks())

        current_time = SDL.GetPerformanceCounter()
        delta_time = current_time - previous_time
        previous_time = current_time

        for val in snap_vals {
            if abs(delta_time - val) < max_deviation {
                delta_time = val
            }
        }

        frame_time_buffer_push(&frame_time_buffer, delta_time)
        delta_time = frame_time_buffer_average(&frame_time_buffer, &averager_res)
        delta_time += averager_res / 4
        averager_res %= 4

        accumulator += delta_time

        process_input(quit_handler)

        for ; accumulator > target_frame_clocks; accumulator -= target_frame_clocks {
            move_camera(FIXED_DELTA_TIME)
            // gotta fix this
            // rotate_transforms(elapsed_time, &transform_queue)
        }

        gl.Viewport(0, 0, WIDTH, HEIGHT)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        draw_triangles(elapsed_time)
        SDL.GL_SwapWindow(window)
    }
}

FrameTimeBuffer :: struct {
    insert_at : i32,
    values : [4]u64
}

frame_time_buffer_init :: proc(buffer: ^FrameTimeBuffer, targetFrameTime: u64) {
    buffer.values = { targetFrameTime, targetFrameTime, targetFrameTime, targetFrameTime }
}

frame_time_buffer_push :: proc(buffer: ^FrameTimeBuffer, value: u64) {
    buffer.values[buffer.insert_at] = value
    buffer.insert_at = (buffer.insert_at + 1) % 4
}

frame_time_buffer_average :: proc(buffer: ^FrameTimeBuffer, res: ^u64) -> (u64) {
    sum : u64
    for val in buffer.values {
        sum += val
    }
    res^ += sum % 4
    return sum / 4
}