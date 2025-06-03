package main
import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:fmt"

// move speed
MAX_PLAYER_SPEED: f32: 50.0
MAX_FALL_SPEED: f32: 60.0
AIR_SPEED :: 100.0
SLOPE_SPEED :: 80.0 
P_ACCEL: f32: 150.0
GROUND_BUNNY_V_SPEED: f32: 70
GROUND_BUNNY_H_SPEED: f32: 30
MIN_BUNNY_XZ_VEL: f32: 20.0

// jump
P_JUMP_SPEED: f32: 60.0
WALL_JUMP_FORCE :: 25 
SLOPE_V_JUMP_FORCE :: 50 
SLOPE_JUMP_FORCE :: 40

// forces
GROUND_FRICTION :: 0.05
GRAV: f32: 135
WALL_GRAV: f32: 20 
SLOPE_GRAV: f32: 60 

// input
COYOTE_TIME ::  150
BUNNY_DASH_DEBOUNCE: f32: 400
BUNNY_WINDOW: f32: 100

// dash
DASH_SPD: f32: 75.0
DASH_LEN: f32: 175 
DASH_DIST: f32: 15.0

// physics
GROUND_RAY_LEN ::  2.0
GROUNDED_RADIUS: f32: 0.01 
GROUNDED_RADIUS2 :: GROUNDED_RADIUS * GROUNDED_RADIUS
GROUND_OFFSET: f32 = 1.0 

// rendering
TRAIL_SIZE :: 50 
PARTICLE_DISPLACEMENT_LERP :: 0.25
TGT_PARTICLE_DISPLACEMENT_LERP :: 0.4


Player_States :: enum {
    ON_GROUND,
    ON_WALL,
    ON_SLOPE,
    IN_AIR,
    DASHING 
}

Player_State :: struct {
    state: Player_States,
    dash_start_pos: [3]f32,
    dash_end_pos: [3]f32,
    dash_dir: [3]f32,
    touch_pt: [3]f32,
    touch_time: f32,
    crunch_pt: [3]f32,
    bunny_hop_y: f32,
    crunch_time: f32,
    last_dash: f32,

    position: [3]f32,
    velocity: [3]f32,

    can_press_jump: bool,
    can_press_dash: bool,
    jump_pressed_time: f32,
    dash_time: f32,
    dash_end_time: f32,
    dashing: bool,

    left_ground: f32,
    left_slope: f32,
    left_wall: f32,

    contact_ray: [3]f32,
    ground_x: [3]f32,
    ground_z: [3]f32,
    prev_position: [3]f32,

    trail_sample: [3]glm.vec3,
    prev_trail_sample: [3]glm.vec3,
    trail: RingBuffer(TRAIL_SIZE, [3]f32),

    particle_displacement: [3]f32,
    tgt_particle_displacement: [3]f32
}

update_player_velocity :: proc(gs: ^Game_State, elapsed_time: f64, delta_time: f32) {
    ps := &gs.player_state
    is := &gs.input_state

    // update trail
    ring_buffer_push(&ps.trail, [3]f32 {f32(ps.position.x), f32(ps.position.y), f32(ps.position.z)})
    ps.prev_trail_sample = ps.trail_sample
    ps.trail_sample = {ring_buffer_at(ps.trail, -4), ring_buffer_at(ps.trail, -8), ring_buffer_at(ps.trail, -12)}

    move_spd := P_ACCEL
    if ps.state == .ON_SLOPE {
        move_spd = SLOPE_SPEED 
    } else if ps.state == .IN_AIR {
        move_spd = AIR_SPEED
    }

    // process directional input
    input_x: f32 = 0.0
    input_z: f32 = 0.0
    if is.left_pressed do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed do input_z -= 1
    if is.down_pressed do input_z += 1
    input_dir := la.normalize0([2]f32{input_x, input_z})
    if is.hor_axis !=0 || is.vert_axis != 0 {
        input_dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    }
    got_dir_input := is.a_pressed || is.s_pressed || is.d_pressed || is.w_pressed || is.hor_axis != 0 || is.vert_axis != 0

    // move player through air or along ground axes
    grounded := ps.state == .ON_GROUND || ps.state == .ON_SLOPE
    right_vec := grounded ? ps.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? ps.ground_z : [3]f32{0, 0, -1}
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

    // register jump pressed
    if is.z_pressed {
        ps.jump_pressed_time = f32(elapsed_time)
    }

    // clamp xz velocity
    clamped_xz := la.clamp_length(ps.velocity.xz, MAX_PLAYER_SPEED)
    ps.velocity.xz = math.lerp(ps.velocity.xz, clamped_xz, f32(0.05))
    ps.velocity.y = math.clamp(ps.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply ground friction
    if ps.state == .ON_GROUND && !got_dir_input {
        ps.velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity
    if ps.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(ps.contact_ray)
        grav_force := GRAV
        if ps.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if ps.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if ps.state == .ON_WALL || ps.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        ps.velocity += down * grav_force * delta_time
    }

    // bunny hop
    can_bunny_hop := f32(elapsed_time) - ps.last_dash > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := ps.state != .IN_AIR && math.abs(ps.touch_time - ps.jump_pressed_time) < BUNNY_WINDOW
    if got_bunny_hop_input && can_bunny_hop {
        ps.can_press_dash = true
        ps.bunny_hop_y = ps.position.y
        ps.state = .IN_AIR
        ps.velocity.y = GROUND_BUNNY_V_SPEED
        if la.length(ps.velocity.xz) > MIN_BUNNY_XZ_VEL {
            ps.velocity.xz += la.normalize(ps.velocity.xz) * GROUND_BUNNY_H_SPEED
        }
        ps.crunch_pt = ps.position - {0, 0, 0.5}
        ps.crunch_time = f32(elapsed_time)
        ps.last_dash = f32(elapsed_time)
    }

    // jumps
    pressed_jump := is.z_pressed && ps.can_press_jump
    ground_jumped := pressed_jump && (ps.state == .ON_GROUND || (f32(elapsed_time) - ps.left_ground < COYOTE_TIME))
    slope_jumped := pressed_jump && (ps.state == .ON_SLOPE || (f32(elapsed_time) - ps.left_slope < COYOTE_TIME))
    wall_jumped := pressed_jump && (ps.state == .ON_WALL || (f32(elapsed_time) - ps.left_wall < COYOTE_TIME))


    // normal jump
    if ground_jumped {
        ps.velocity.y = P_JUMP_SPEED
        ps.state = .IN_AIR

    // slope jump
    } else if slope_jumped {
        ps.velocity += -la.normalize(ps.contact_ray) * SLOPE_JUMP_FORCE
        ps.velocity.y = SLOPE_V_JUMP_FORCE
        ps.state = .IN_AIR

    // wall jump
    } else if wall_jumped {
        ps.velocity.y = P_JUMP_SPEED
        ps.velocity += -ps.contact_ray * WALL_JUMP_FORCE 
        ps.state = .IN_AIR
    }

    // set particle displacement on jump
    if ground_jumped || slope_jumped || wall_jumped {
        ps.can_press_jump = false
        ps.tgt_particle_displacement = ps.velocity
    }

    // lerp particle displacement toward target
    ps.particle_displacement = la.lerp(ps.particle_displacement, ps.tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
    ps.tgt_particle_displacement = la.lerp(ps.tgt_particle_displacement, ps.velocity, TGT_PARTICLE_DISPLACEMENT_LERP)

    // dash
    pressed_dash := is.x_pressed && ps.can_press_dash
    if pressed_dash && ps.velocity != 0 {
        ps.can_press_dash = false
        ps.dashing = true
        ps.dash_start_pos = ps.position
        dash_input := input_dir == 0 ? la.normalize0(ps.velocity.xz) : input_dir
        ps.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        ps.dash_end_pos = ps.position + DASH_DIST * ps.dash_dir
        ps.dash_time = f32(elapsed_time)
    }

    //end dash
    hit_surface := ps.state == .ON_WALL || grounded
    dash_expired := f32(elapsed_time) > ps.dash_time + DASH_LEN
    if ps.dashing && (hit_surface || dash_expired){
        ps.dash_end_time = f32(elapsed_time)
        ps.dashing = false
        ps.velocity = la.normalize(ps.dash_end_pos - ps.dash_start_pos) * DASH_SPD
        ps.position = ps.dash_end_pos
    }
     
    // dashing
    if ps.dashing {
        ps.velocity = 0
        dash_t := (f32(elapsed_time) - ps.dash_time) / DASH_LEN
        dash_delta := ps.dash_end_pos - ps.dash_start_pos
        ps.position = ps.dash_start_pos; //ps.dash_start_pos + dash_delta * dash_t
    }

    // bunny hop time dilation
    if ps.state != .ON_GROUND && f32(elapsed_time) - ps.crunch_time < 1000 {
        if ps.position.y > ps.bunny_hop_y {
            fact := abs(ps.velocity.y) / GROUND_BUNNY_V_SPEED
            gs.time_mult = clamp(fact * fact * 4.5, 1.15, 1.5)
        } else {
            gs.time_mult = f32(math.lerp(gs.time_mult, 1, f32(0.05)))
        }

    } else {
        gs.time_mult = f32(math.lerp(gs.time_mult, 1, f32(0.05)))
    }

    // debounce jump/dash input
    if !ps.can_press_jump {
        ps.can_press_jump = !is.z_pressed && grounded || ps.state == .ON_WALL
    }
    if !ps.can_press_dash {
        ps.can_press_dash = !is.x_pressed && ps.state == .ON_GROUND
    }

    // handle reset
    if is.r_pressed {
        ps.position = INIT_PLAYER_POS
        ps.velocity = [3]f32 {0, 0, 0}
    }

}

move_player :: proc(gs: ^Game_State, phs: ^Physics_State, elapsed_time: f32, delta_time: f32) {
    pls := &gs.player_state
    pls.prev_position = pls.position

    // if pls.dashing {
    //     pls.velocity = pls.dash_vel
    // }

    init_velocity_len := la.length(pls.velocity)

    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    get_collisions(gs, phs, delta_time, elapsed_time)
    if remaining_vel > 0 {
        loops := 0
        for len(phs.collisions) > 0 && loops < 10 {
            loops += 1
            earliest_coll_t: f32 = 1.1
            earliest_coll_idx := -1
            for coll, idx in phs.collisions {
                if coll.t < earliest_coll_t {
                    earliest_coll_idx = idx
                    earliest_coll_t = coll.t
                }
            }
            earliest_coll := phs.collisions[earliest_coll_idx]
            move_amt := (remaining_vel * (earliest_coll_t) - .01) * velocity_normal
            pls.position += move_amt
            remaining_vel *= 1.0 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            pls.velocity = (velocity_normal * (remaining_vel)) / delta_time
            get_collisions(gs, phs, delta_time, elapsed_time)
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }
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

