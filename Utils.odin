package main

FrameTimeBuffer :: struct {
    insert_at : i32,
    values : [4]f64
}

frame_time_buffer_init :: proc(buffer: ^FrameTimeBuffer, targetFrameTime: f64) {
    buffer.values = { targetFrameTime, targetFrameTime, targetFrameTime, targetFrameTime }
}

frame_time_buffer_push :: proc(buffer: ^FrameTimeBuffer, value: f64) {
    buffer.values[buffer.insert_at] = value
    buffer.insert_at = (buffer.insert_at + 1) % 4
}

frame_time_buffer_average :: proc(buffer: ^FrameTimeBuffer) -> f64 {
    sum : f64
    for val in buffer.values {
        sum += val
    }
    return sum / 4.0
}