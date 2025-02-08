package main
import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:fmt"

// should update this
Player_Input_State :: struct {
    got_jump: bool,
    got_input: bool,
    got_dir: bool,
    dir: la.Vector2f64,
}

Player_State :: struct {
    position: [3]f32,
    velocity: [3]f32,
    trail: [dynamic]glm.vec3
}

MAX_PLAYER_SPEED: f32: 10.0
P_JUMP_SPEED: f32: 15.0
P_ACCEL: f32: 20.0
GRAV: f32: 0.25
TRAIL_SIZE :: 50 

update_player_velocity :: proc(is: Input_State, ps: ^Player_State, elapsed_time: f64, delta_time: f32) {
    
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
    //if is.spc_pressed && ps.position.y == 0 {
    //    ps.velocity.y = P_JUMP_SPEED
    //}
    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = clamped_xz
    ps.velocity.xz *= math.pow(0.05, delta_time)
    //ps.velocity.y = 0
    ps.velocity.y -= GRAV
    //if ps.position.y == 0 {
    //    ps.velocity.y = 0
    //}
    if is.spc_pressed && ps.position.y == 0 {
        ps.velocity.y = P_JUMP_SPEED
    }
    //fmt.println(ps.velocity)
}

move_player :: proc(gs: ^Game_State, phs: ^Physics_State, delta_time: f32) {
    pls := &gs.player_state

    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    if remaining_vel > 0 {
        get_collisions(gs, phs, delta_time)
        loops := 0
        for len(phs.collisions) > 0 {
            earliest_coll_t :f32 = 1.1
            earliest_coll_idx := -1
            for coll, idx in phs.collisions {
                if coll.t < earliest_coll_t {
                    earliest_coll_idx = idx
                    earliest_coll_t = coll.t
                }
            }
            //fmt.println(earliest_coll_t)
            earliest_coll := phs.collisions[earliest_coll_idx]
            move_amt := remaining_vel * earliest_coll_t * velocity_normal + earliest_coll.normal * .01
            pls.position += move_amt
            remaining_vel *= 1 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            pls.velocity = velocity_normal * remaining_vel
            get_collisions(gs, phs, delta_time)
            if loops == 4 {
                fmt.println("unhandled collisions")
            }
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len

        pls.position.y = max(pls.position.y, 0)
        if pls.position.y == 0 {
            pls.velocity.y = 0
        }
        //if pls.position.y == 0 {
        //    pls.velocity.y = 0
        //}
    }
}

