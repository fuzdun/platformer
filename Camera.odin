package main
import "core:math"

cx : f64 = 0
cy : f64 = 0
cz : f64 = -2 
cvx : f64 = 0
cvy : f64 = 0
cvz : f64 = 0
C_SPD : f64 : 0.0000005
damping : f64 = 0.999


move_player :: proc(delta_time: f64) {
    if u_pressed do cvy -= C_SPD * delta_time
    if d_pressed do cvy += C_SPD * delta_time
    if r_pressed do cvx -= C_SPD * delta_time
    if l_pressed do cvx += C_SPD * delta_time
    if f_pressed do cvz += C_SPD * delta_time
    if b_pressed do cvz -= C_SPD * delta_time

    cx += cvx * delta_time
    cy += cvy * delta_time
    cz += cvz * delta_time
    cvx *= math.pow(damping, delta_time)
    cvy *= math.pow(damping, delta_time)
    cvz *= math.pow(damping, delta_time)
}