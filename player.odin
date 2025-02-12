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
    trail: [dynamic]glm.vec3,
    on_ground: bool,
    ground_x: [3]f32,
    ground_z: [3]f32,
    left_ground: f32
}

GROUND_FRICTION :: 0.05
MAX_PLAYER_SPEED: f32: 40.0
P_JUMP_SPEED: f32: 25.0
P_ACCEL: f32: 75.0
GRAV: f32: 30
TRAIL_SIZE :: 50 
GROUND_RAY: [3]f32: {0, -0.6, 0}
GROUNDED_RADIUS: f32: 0.25 
GROUNDED_RADIUS2:: GROUNDED_RADIUS * GROUNDED_RADIUS
GROUND_VERTICAL_OFFSET: [3]f32: {0, -0.00, 0}
AIR_SPEED :: 0.8

update_player_velocity :: proc(is: Input_State, ps: ^Player_State, elapsed_time: f64, delta_time: f32) {
    
    //fmt.println(f32(elapsed_time) - ps.left_ground)
    pop(&ps.trail)
    new_pt: [3]f32 = {f32(ps.position.x), f32(ps.position.y), f32(ps.position.z)}
    inject_at(&ps.trail, 0, new_pt)
    right_vec := ps.on_ground || ps.position.y == 0 ? ps.ground_x : [3]f32{1, 0, 0} * AIR_SPEED
    fwd_vec := ps.on_ground || ps.position.y == 0 ? ps.ground_z : [3]f32{0, 0, -1} * AIR_SPEED
    if is.a_pressed {
       ps.velocity -= P_ACCEL * delta_time * right_vec
    }
    if is.d_pressed {
        ps.velocity += P_ACCEL * delta_time * right_vec
    }
    if is.w_pressed {
        ps.velocity += P_ACCEL * delta_time * fwd_vec
    }
    if is.s_pressed {
        ps.velocity -= P_ACCEL * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        ps.velocity += P_ACCEL * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        ps.velocity += P_ACCEL * delta_time * is.vert_axis * fwd_vec
    }
    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = clamped_xz
    got_dir_input := is.a_pressed || is.s_pressed || is.d_pressed || is.w_pressed || is.hor_axis != 0 || is.vert_axis != 0
    if (ps.on_ground || ps.position.y == 0) && !got_dir_input {
        ps.velocity.xz *= math.pow(GROUND_FRICTION, delta_time)
        //ps.velocity.xz *= GROUND_FRICTION
    }
    if !ps.on_ground {
        ps.velocity.y -= GRAV * delta_time
    }
    if is.spc_pressed && ((ps.on_ground || ps.position.y == 0) || (f32(elapsed_time) - ps.left_ground < 150)) {
        ps.velocity.y = P_JUMP_SPEED
    }
    //fmt.println(is.hor_axis)
}

move_player :: proc(gs: ^Game_State, phs: ^Physics_State, elapsed_time: f32, delta_time: f32) {
    pls := &gs.player_state

    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    if remaining_vel > 0 {
        get_collisions(gs, phs, delta_time, elapsed_time)
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
            get_collisions(gs, phs, delta_time, elapsed_time)
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
    }
}

