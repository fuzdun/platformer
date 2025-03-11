package main

import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:fmt"
import "core:time"

@(private="file")
quit_app := false

frame_loop :: proc(window: ^SDL.Window, gs: ^Game_State, rs: ^Render_State, ss: ^ShaderState, ps: ^Physics_State) {
    //TARGET_FRAME_RATE :: 240.0
    TARGET_FRAME_RATE :: 6.0
    FIXED_DELTA_TIME :: f32(1.0 / TARGET_FRAME_RATE)
    clocks_per_second := i64(SDL.GetPerformanceFrequency())
    target_frame_clocks := clocks_per_second / TARGET_FRAME_RATE
    max_deviation := clocks_per_second / 5000

    snap_hz: i64 = 60
    current_display_mode: SDL.DisplayMode
    if SDL.GetCurrentDisplayMode(0, &current_display_mode) == 0 {
        snap_hz = i64(current_display_mode.refresh_rate)
    }
    snap_hz = i64(clocks_per_second) / snap_hz
    snap_vals : [8]i64 = { snap_hz, snap_hz * 2, snap_hz * 3, snap_hz * 4, snap_hz * 5, snap_hz * 6, snap_hz * 7, snap_hz * 8 }
    
    frame_time_buffer : FrameTimeBuffer
    frame_time_buffer_init(&frame_time_buffer, target_frame_clocks)

    current_time, previous_time, delta_time, averager_res, accumulator : i64
    previous_time = i64(SDL.GetPerformanceCounter())

    resync := true
    quit_handler :: proc () { quit_app = true }

    for !quit_app {
        if quit_app do break
        //update_start := time.now()

        elapsed_time := f64(SDL.GetTicks())

        current_time = i64(SDL.GetPerformanceCounter())
        delta_time = current_time - previous_time
        previous_time = current_time

        if delta_time > target_frame_clocks * 8 {
            delta_time = target_frame_clocks
        }
        delta_time = max(0, delta_time)

        for val in snap_vals {
            if abs(delta_time - val) < max_deviation {
                delta_time = val
                break
            }
        }

        frame_time_buffer_push(&frame_time_buffer, delta_time)
        delta_time, averager_res = frame_time_buffer_average(&frame_time_buffer, averager_res)
        delta_time += averager_res / 4
        averager_res %= 4

        accumulator += delta_time

        if accumulator > target_frame_clocks * 8 {
            resync = true
        }


        if(resync) {
            accumulator = 0;
            delta_time = target_frame_clocks;
            resync = false;
        }

        // Handle input
        process_input(&gs.input_state, quit_handler)

        for accumulator >= target_frame_clocks {
            // Fixed update
            //fmt.println("update")
            game_update(gs, ps, rs, elapsed_time, FIXED_DELTA_TIME)
            accumulator -= target_frame_clocks 
        }

        // Render
        gl.Viewport(0, 0, WIDTH, HEIGHT)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        
        //fmt.println("update time:", time.since(update_start))
        //draw_start := time.now()
        update_vertices(gs, rs)
        draw_triangles(gs, rs, ss, ps, elapsed_time, f64(accumulator) / f64(target_frame_clocks))

        //swap_start := time.now()
        SDL.GL_SwapWindow(window)
        //fmt.println("draw time:", time.since(draw_start))
        //fmt.println("swap time", time.since(swap_start))
        //fmt.println("frame time", time.since(update_start))
    }
}

FrameTimeBuffer :: struct {
    insert_at : i32,
    values : [4]i64
}

frame_time_buffer_init :: proc(buffer: ^FrameTimeBuffer, targetFrameTime: i64) {
    buffer.values = { targetFrameTime, targetFrameTime, targetFrameTime, targetFrameTime }
}

frame_time_buffer_push :: proc(buffer: ^FrameTimeBuffer, value: i64) {
    buffer.values[buffer.insert_at] = value
    buffer.insert_at = (buffer.insert_at + 1) % 4
}

frame_time_buffer_average :: proc(buffer: ^FrameTimeBuffer, res: i64) -> (i64, i64) {
    sum : i64 = 0
    for val in buffer.values {
        sum += val
    }
    return sum / 4, res + sum % 4
}

