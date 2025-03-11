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
    touch_pt: [3]f32,
    touch_time: f32,
    crunch_pt: [3]f32,
    crunch_time: f32,
    last_dash: f32,
    jump_pressed_time: f32,

    can_jump: bool,
    can_dash: bool,
    dash_time: f32,
    dashing: bool,
    dash_vel: glm.vec3,
    on_ground: bool,
    on_wall: bool,
    on_slope: bool,

    left_ground: f32,
    left_slope: f32,

    contact_ray: [3]f32,
    ground_x: [3]f32,
    ground_z: [3]f32,
    sonar_time: f32,
    prev_position: [3]f32,
    trail_sample: [3]glm.vec3,
    prev_trail_sample: [3]glm.vec3
}

GROUND_FRICTION :: 0.05
MAX_PLAYER_SPEED: f32: 50.0
P_JUMP_SPEED: f32: 30.0
P_ACCEL: f32: 150.0
DASH_SPD: f32: 75.0
DASH_LEN: f32: 150 
BUNNY_WINDOW: f32: 100
BUNNY_DEBOUNCE: f32: 400
GROUND_BUNNY_ACCEL: f32: 30
GRAV: f32: 80
WALL_GRAV: f32: 30 
SLOPE_GRAV: f32: 10 
WALL_JUMP_FORCE :: 15 
SLOPE_V_JUMP_FORCE :: 30 
SLOPE_JUMP_FORCE :: 20
TRAIL_SIZE :: 50 
GROUND_RAY_LEN ::  2.0
GROUNDED_RADIUS: f32: 0.01 
GROUNDED_RADIUS2 :: GROUNDED_RADIUS * GROUNDED_RADIUS
GROUND_OFFSET: f32 = .5
AIR_SPEED :: 120.0
SLOPE_SPEED :: 25.0 

update_player_velocity :: proc(is: Input_State, ps: ^Player_State, elapsed_time: f64, delta_time: f32) {
    if is.q_pressed {
        ps.sonar_time = f32(elapsed_time)
    }
    pop(&ps.trail)
    new_pt: [3]f32 = {f32(ps.position.x), f32(ps.position.y), f32(ps.position.z)}
    inject_at(&ps.trail, 0, new_pt)
    ps.prev_trail_sample = ps.trail_sample
    ps.trail_sample = {ps.trail[2], ps.trail[4], ps.trail[8]}
    move_spd := P_ACCEL
    if ps.on_slope {
        move_spd = SLOPE_SPEED 
    } else if !ps.on_ground {
        move_spd = AIR_SPEED
    }
    right_vec := (ps.on_ground || ps.on_slope) ? ps.ground_x : [3]f32{1, 0, 0}
    fwd_vec := (ps.on_ground || ps.on_slope) ? ps.ground_z : [3]f32{0, 0, -1}
    if is.left_pressed {
       ps.velocity -= move_spd * delta_time * right_vec
    }
    if is.right_pressed {
        ps.velocity += move_spd * delta_time * right_vec
    }
    if is.up_pressed {
        ps.velocity += move_spd * delta_time * fwd_vec
    }
    if is.down_pressed {
        ps.velocity -= move_spd * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        ps.velocity += move_spd * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        ps.velocity += move_spd * delta_time * is.vert_axis * fwd_vec
    }

    input_x: f32 = 0.0
    input_z: f32 = 0.0
    if is.left_pressed do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed do input_z -= 1
    if is.down_pressed do input_z += 1
    input_dir := la.normalize([2]f32{input_x, input_z})

    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = math.lerp(ps.velocity.xz, clamped_xz, f32(0.05))
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
    if is.z_pressed && ps.can_jump {
        ps.jump_pressed_time = f32(elapsed_time)
    }
    if ps.on_ground && ps.touch_pt != 0 && math.abs(ps.touch_time - ps.jump_pressed_time) < BUNNY_WINDOW && f32(elapsed_time) - ps.last_dash > BUNNY_DEBOUNCE {
        ps.on_ground = false
        ps.velocity.y = P_JUMP_SPEED
        ps.velocity.xz += la.normalize(ps.velocity.xz) * GROUND_BUNNY_ACCEL
        ps.crunch_pt = ps.position - {0, 0, 0.5}
        ps.crunch_time = f32(elapsed_time)
        ps.last_dash = f32(elapsed_time)
    }
    if is.z_pressed && ps.can_jump && (ps.on_ground || (f32(elapsed_time) - ps.left_ground < 150)) {
        ps.velocity.y = P_JUMP_SPEED
        ps.on_ground = false
    } else if is.z_pressed && ps.can_jump && (ps.on_slope || (f32(elapsed_time) - ps.left_slope < 150)) {
        // add surface dir to jump but set y component to P_JUMP_SPEED
        ps.velocity += -la.normalize(ps.contact_ray) * SLOPE_JUMP_FORCE
        ps.velocity.y = SLOPE_V_JUMP_FORCE
        //ps.velocity += -la.normalize(ps.contact_ray) * P_JUMP_SPEED 
        ps.on_slope = false
    }
    if is.z_pressed && ps.on_wall && ps.can_jump {
        ps.velocity.y = P_JUMP_SPEED
        ps.velocity += -ps.contact_ray * WALL_JUMP_FORCE 
        ps.on_wall = false
    }

    if !ps.can_dash {
        ps.can_dash = !is.x_pressed && ps.on_ground
    }

    if is.x_pressed && ps.can_dash && ps.velocity != 0{
        //fmt.println("start dash")
        ps.can_dash = false
        ps.dashing = true
        dash_dir := input_dir != 0 ? input_dir : la.normalize(ps.velocity.xz)
        tgt_dash_vel := [3]f32 {dash_dir.x, 0.0, dash_dir.y} * DASH_SPD 
        ps.dash_vel.xz = la.clamp_length(tgt_dash_vel.xz + ps.velocity.xz, DASH_SPD)
        ps.dash_time = f32(elapsed_time)
    }
    if ps.dashing && f32(elapsed_time) > ps.dash_time + DASH_LEN {
        ps.dashing = false
        //fmt.println("end dash")
    }
    
    ps.can_jump = !is.z_pressed
}

move_player :: proc(gs: ^Game_State, phs: ^Physics_State, elapsed_time: f32, delta_time: f32) {
    pls := &gs.player_state
    pls.prev_position = pls.position

    if pls.dashing {
        pls.velocity = pls.dash_vel
    }

    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    get_collisions(gs, phs, delta_time, elapsed_time)
    if remaining_vel > 0 {
        loops := 0
        if len(phs.collisions) > 0 {
            fmt.println("collisions:", len(phs.collisions))
        }
        for len(phs.collisions) > 0 {
            earliest_coll_t: f32 = 1.1
            earliest_coll_idx := -1
            for coll, idx in phs.collisions {
                if coll.t < earliest_coll_t {
                    earliest_coll_idx = idx
                    earliest_coll_t = coll.t
                }
            }
            earliest_coll := phs.collisions[earliest_coll_idx]
            fmt.println("coll normal:", earliest_coll.normal)
            move_amt := (remaining_vel - .01) * earliest_coll_t * velocity_normal
            pls.position += move_amt
            remaining_vel *= 1.0 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            fmt.println("new normal:", velocity_normal)
            pls.velocity = velocity_normal * (remaining_vel + .01)
            get_collisions(gs, phs, delta_time, elapsed_time)
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }
    //pls.prev_mat = pls.cur_mat
    //pls.cur_mat = construct_player_matrix(pls)
}

interpolated_player_pos :: proc(ps: ^Player_State, t: f32) -> [3]f32 {
    return math.lerp(ps.prev_position, ps.position, t) 
}

interpolated_trail :: proc(ps: ^Player_State, t: f32) -> [3]glm.vec3 {
    return math.lerp(ps.prev_trail_sample, ps.trail_sample, t)
}

interpolated_player_matrix :: proc(ps: ^Player_State, t: f32) -> matrix[4, 4]f32 {
    i_pos := math.lerp(ps.prev_position, ps.position, t) 
    rot := I_MAT
    offset := glm.mat4Translate({f32(i_pos.x), f32(i_pos.y), f32(i_pos.z)})
    return rot * offset
}

//construct_player_matrix :: proc(ps: ^Player_State) -> matrix[4, 4]f32 {
//    pos := ps.position
//    rot := I_MAT
//    offset := glm.mat4Translate({f32(pos.x), f32(pos.y), f32(pos.z)})
//    return rot * offset
//}

