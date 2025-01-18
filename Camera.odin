package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

cx : f64 = 0
cy : f64 = 0
cz : f64 = -2 
cvx : f64 = 0
cvy : f64 = 0
cvz : f64 = 0
C_SPD : f64 : 0.25
turn_speed : f64 : .75
damping : f64 = 0.5
crx : f64 = 0
cry : f64 = 0
crz : f64 = 0

move_camera :: proc(delta_time: f64) {
    if spc_pressed {
        if f_pressed do crx -= turn_speed * delta_time
        if b_pressed do crx += turn_speed * delta_time
        if r_pressed do cry += turn_speed * delta_time
        if l_pressed do cry -= turn_speed * delta_time
        if u_pressed do crz += turn_speed * delta_time
        if d_pressed do crz -= turn_speed * delta_time
    } else {
        rot := glm.mat4Rotate({1, 0, 0}, f32(crx)) * glm.mat4Rotate({ 0, 1, 0 }, f32(cry))
        fwd := glm.vec4({0, 0, 1, 1}) * rot
        up := glm.vec4({0, 1, 0, 1}) * rot
        right := glm.vec4({1, 0, 0, 1}) * rot
        if u_pressed {
            cvx -= f64(up.x) * C_SPD * delta_time
            cvy -= f64(up.y) * C_SPD * delta_time
            cvz -= f64(up.z) * C_SPD * delta_time
        }
        if d_pressed {
            cvx += f64(up.x) * C_SPD * delta_time
            cvy += f64(up.y) * C_SPD * delta_time
            cvz += f64(up.z) * C_SPD * delta_time
        }
        if l_pressed {
            cvx += f64(right.x) * C_SPD * delta_time
            cvy += f64(right.y) * C_SPD * delta_time
            cvz += f64(right.z) * C_SPD * delta_time
        }
        if r_pressed {
            cvx -= f64(right.x) * C_SPD * delta_time
            cvy -= f64(right.y) * C_SPD * delta_time
            cvz -= f64(right.z) * C_SPD * delta_time
        }
        if f_pressed {
            cvx += f64(fwd.x) * C_SPD * delta_time
            cvy += f64(fwd.y) * C_SPD * delta_time
            cvz += f64(fwd.z) * C_SPD * delta_time
        }
        if b_pressed {
            cvx -= f64(fwd.x) * C_SPD * delta_time
            cvy -= f64(fwd.y) * C_SPD * delta_time
            cvz -= f64(fwd.z) * C_SPD * delta_time
        }
        // if d_pressed do cvy += C_SPD * delta_time
        // if r_pressed do cvx -= C_SPD * delta_time
        // if l_pressed do cvx += C_SPD * delta_time
        // if f_pressed do cvz += C_SPD * delta_time
        // if b_pressed do cvz -= C_SPD * delta_time
    }


    cx += cvx * delta_time
    cy += cvy * delta_time
    cz += cvz * delta_time

    if !(u_pressed || d_pressed || r_pressed || l_pressed || f_pressed || b_pressed) {
        cvx *= math.pow(damping, delta_time)
        cvy *= math.pow(damping, delta_time)
        cvz *= math.pow(damping, delta_time)
        vec : [3]f64 = { cvx, cvy, cvz }
        len := la.vector_length(vec)
        if len < 0.0005 {
            cvx, cvy, cvz = 0, 0, 0
        }
    }
}