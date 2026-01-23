package main

Time_State :: struct {
    time_mult: f32
}

init_time_state :: proc(ts: ^Time_State) {
    ts.time_mult = 1.0
}

