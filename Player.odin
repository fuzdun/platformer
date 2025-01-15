package main
import "core:math"

px : f64 = 0
py : f64 = 0
pz : f64 = -2 
pvx : f64 = 0
pvy : f64 = 0
pvz : f64 = 0
P_SPD : f64 : 0.0000005
damping : f64 = 0.999


move_player :: proc(delta_time: f64) {
    if u_pressed do pvy -= P_SPD * delta_time
    if d_pressed do pvy += P_SPD * delta_time
    if r_pressed do pvx -= P_SPD * delta_time
    if l_pressed do pvx += P_SPD * delta_time
    if f_pressed do pvz += P_SPD * delta_time
    if b_pressed do pvz -= P_SPD * delta_time

    px += pvx * delta_time
    py += pvy * delta_time
    pz += pvz * delta_time
    pvx *= math.pow(damping, delta_time)
    pvy *= math.pow(damping, delta_time)
    pvz *= math.pow(damping, delta_time)
}