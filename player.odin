package main
import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:fmt"

Input_State :: struct {
    a_pressed: bool,
    d_pressed: bool,
    s_pressed: bool,
    w_pressed: bool,
    spc_pressed: bool,
}

// should update this
Player_Input_State :: struct {
    got_jump: bool,
    got_input: bool,
    got_dir: bool,
    dir: la.Vector2f64,
}

Player_State :: struct {
    position: [3]f64,
    velocity: [3]f64,
    trail: [dynamic]glm.vec3
}

MAX_PLAYER_SPEED := 10.0
P_JUMP_SPEED := 10.0
P_ACCEL := 20.0
GRAV := 0.25
TRAIL_SIZE :: 50 

move_player :: proc(is: Input_State, ps: ^Player_State, elapsed_time: f64, delta_time: f64) {
    
    pop(&ps.trail)
    new_pt: [3]f32 = {f32(ps.position.x), f32(ps.position.y), f32(ps.position.z)}
    inject_at(&ps.trail, 0, new_pt)

    if is.a_pressed {
       ps.velocity.x -= P_ACCEL * delta_time
    }
    if is.d_pressed {
        ps.velocity.x += P_ACCEL * delta_time
    }
    if is.w_pressed {
        ps.velocity.z -= P_ACCEL * delta_time
    }
    if is.s_pressed {
        ps.velocity.z += P_ACCEL * delta_time
    }
    if is.spc_pressed && ps.position.y == 0 {
        ps.velocity.y = P_JUMP_SPEED
    }
    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = clamped_xz
    
    got_input := is.a_pressed || is.d_pressed || is.w_pressed || is.s_pressed

    //if !got_input {
        ps.velocity.xz *= math.pow(0.05, delta_time)
    //}

    ps.velocity.y -= GRAV

    ps.position.x += ps.velocity.x * delta_time
    ps.position.y += ps.velocity.y * delta_time
    ps.position.z += ps.velocity.z * delta_time

    ps.position.y = max(ps.position.y, 0)
}

