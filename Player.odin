package main

px : f64 = 0
py : f64 = 0
pvx : f64 = 0
pvy : f64 = 0

process_inputs :: proc() {
    if u_pressed do pvy -= P_SPD
    if d_pressed do pvy += P_SPD
    if r_pressed do pvx += P_SPD
    if l_pressed do pvx -= P_SPD
}

move_player :: proc(delta_time: f64) {
    px += pvx * delta_time
    py += pvy * delta_time
}