package main
import "core:math"
import la "core:math/linalg"
import "core:fmt"

px : f64 = 0
py : f64 = 0
pz : f64 = 0

pv: [3]f64 = {0, 0, 0}

MAX_PLAYER_SPEED := 10.0
P_JUMP_SPEED := 10.0
P_ACCEL := 20.0
GRAV := 0.25

move_player :: proc(elapsed_time: f64, delta_time: f64) {
    if a_pressed {
       pv.x += P_ACCEL * delta_time
    }
    if d_pressed {
        pv.x -= P_ACCEL * delta_time
    }
    if w_pressed {
        pv.z += P_ACCEL * delta_time
    }
    if s_pressed {
        pv.z -= P_ACCEL * delta_time
    }
    if spc_pressed && py == 0 {
        pv.y = - P_JUMP_SPEED
    }
    //if q_pressed {
    //    pv.y += P_ACCEL * delta_time
    //}
    //if e_pressed {
    //    pv.y -= P_ACCEL * delta_time
    //}
    clamped_xz := la.clamp_length(pv.xz, MAX_PLAYER_SPEED)
    pv.xz = clamped_xz
    
    got_input := a_pressed || d_pressed || w_pressed || s_pressed

    //if !got_input {
        pv.xz *= math.pow(0.05, delta_time)
    //}

    pv.y += GRAV

    px += pv.x * delta_time
    py += pv.y * delta_time
    pz += pv.z * delta_time

    py = min(py, 0)
}

