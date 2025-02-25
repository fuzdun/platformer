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
    can_jump: bool,
    position: [3]f32,
    velocity: [3]f32,
    trail: [dynamic]glm.vec3,
    crunch_pt: [3]f32,
    crunch_time: f32,
    on_ground: bool,
    on_wall: bool,
    on_slope: bool,
    contact_ray: [3]f32,
    ground_x: [3]f32,
    ground_z: [3]f32,
    left_ground: f32,
    left_slope: f32
}

GROUND_FRICTION :: 0.05
MAX_PLAYER_SPEED: f32: 40.0
P_JUMP_SPEED: f32: 25.0
P_ACCEL: f32: 75.0
GRAV: f32: 40
WALL_GRAV: f32: 15
SLOPE_GRAV: f32: 5
WALL_JUMP_FORCE :: 30
SLOPE_V_JUMP_FORCE :: 15
SLOPE_JUMP_FORCE :: 10
TRAIL_SIZE :: 50 
GROUND_RAY_LEN ::  2.0
GROUNDED_RADIUS: f32: 0.01 
GROUNDED_RADIUS2 :: GROUNDED_RADIUS * GROUNDED_RADIUS
GROUND_OFFSET: f32 = .5
AIR_SPEED :: 35.0
SLOPE_SPEED :: 25.0 

update_player_velocity :: proc(is: Input_State, ps: ^Player_State, elapsed_time: f64, delta_time: f32) {
    pop(&ps.trail)
    new_pt: [3]f32 = {f32(ps.position.x), f32(ps.position.y), f32(ps.position.z)}
    inject_at(&ps.trail, 0, new_pt)
    move_spd := P_ACCEL
    if ps.on_slope {
        move_spd = SLOPE_SPEED 
    } else if !ps.on_ground {
        move_spd = AIR_SPEED
    }
    right_vec := (ps.on_ground || ps.on_slope) ? ps.ground_x : [3]f32{1, 0, 0}
    fwd_vec := (ps.on_ground || ps.on_slope) ? ps.ground_z : [3]f32{0, 0, -1}
    if is.a_pressed {
       ps.velocity -= move_spd * delta_time * right_vec
    }
    if is.d_pressed {
        ps.velocity += move_spd * delta_time * right_vec
    }
    if is.w_pressed {
        ps.velocity += move_spd * delta_time * fwd_vec
    }
    if is.s_pressed {
        ps.velocity -= move_spd * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        ps.velocity += move_spd * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        ps.velocity += move_spd * delta_time * is.vert_axis * fwd_vec
    }
    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = clamped_xz
    got_dir_input := is.a_pressed || is.s_pressed || is.d_pressed || is.w_pressed || is.hor_axis != 0 || is.vert_axis != 0
    if ps.on_ground && !got_dir_input {
        ps.velocity *= math.pow(GROUND_FRICTION, delta_time)
    }
    if !ps.on_ground {
        down: [3]f32 = {0, -1, 0}
        grav_vec := GRAV * down
        norm_contact := la.normalize(ps.contact_ray)
        if ps.on_wall {
            grav_vec -= la.dot(norm_contact, grav_vec) * norm_contact
        } else if ps.on_slope {
            grav_vec -= la.dot(norm_contact, grav_vec) * norm_contact 
        }
        ps.velocity += grav_vec * delta_time
    }
    if is.spc_pressed && ps.can_jump && (ps.on_ground || (f32(elapsed_time) - ps.left_ground < 150)) {
        ps.velocity.y = P_JUMP_SPEED
        ps.on_ground = false
    } else if is.spc_pressed && ps.can_jump && (ps.on_slope || (f32(elapsed_time) - ps.left_slope < 150)) {
        // add surface dir to jump but set y component to P_JUMP_SPEED
        ps.velocity += -la.normalize(ps.contact_ray) * SLOPE_JUMP_FORCE
        ps.velocity.y = SLOPE_V_JUMP_FORCE
        //ps.velocity += -la.normalize(ps.contact_ray) * P_JUMP_SPEED 
        ps.on_slope = false
    }
    if is.spc_pressed && ps.on_wall && ps.can_jump {
        ps.velocity.y = P_JUMP_SPEED
        ps.velocity += -ps.contact_ray * WALL_JUMP_FORCE 
        ps.on_wall = false
        ps.crunch_pt = ps.position
        ps.crunch_time = f32(elapsed_time)
    }
    ps.can_jump = !is.spc_pressed
}

move_player :: proc(gs: ^Game_State, phs: ^Physics_State, elapsed_time: f32, delta_time: f32) {
    pls := &gs.player_state

    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    get_collisions(gs, phs, delta_time, elapsed_time)
    if remaining_vel > 0 {
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
            earliest_coll := phs.collisions[earliest_coll_idx]
            move_amt := remaining_vel * earliest_coll_t * velocity_normal + earliest_coll.normal * .01
            pls.position += move_amt
            remaining_vel *= 1 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            pls.velocity = velocity_normal * remaining_vel
            get_collisions(gs, phs, delta_time, elapsed_time)
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }
}

