package main
import "core:math"
import la "core:math/linalg"
import "core:fmt"

px : f64 = 0
py : f64 = 0
pz : f64 = 0

pv: [3]f64 = {0, 0, 0}

MAX_PLAYER_SPEED := 0.1
P_ACCEL := 0.2

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
    pv = la.clamp_length(pv, MAX_PLAYER_SPEED)
    
    got_input := a_pressed || d_pressed || w_pressed || s_pressed

    if !got_input {
        pv *= math.pow(0.01, delta_time)
    }

    px += pv.x
    py += pv.y
    pz += pv.z

}

