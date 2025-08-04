package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"

CRACK_DELAY :: 15000
BREAK_DELAY :: 1500


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, elapsed_time: f32, delta_time: f32) {

    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================

    // update trail
    ring_buffer_push(&pls.trail, [3]f32 {f32(pls.position.x), f32(pls.position.y), f32(pls.position.z)})
    pls.prev_trail_sample = pls.trail_sample
    pls.trail_sample = {ring_buffer_at(pls.trail, -4), ring_buffer_at(pls.trail, -8), ring_buffer_at(pls.trail, -12)}

    move_spd := P_ACCEL
    if pls.contact_state.state == .ON_SLOPE {
        move_spd = SLOPE_SPEED 
    } else if pls.contact_state.state == .IN_AIR {
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

    // adjust velocity along air or ground axes
    grounded := pls.contact_state.state == .ON_GROUND || pls.contact_state.state == .ON_SLOPE
    right_vec := grounded ? pls.contact_state.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? pls.contact_state.ground_z : [3]f32{0, 0, -1}
    if is.left_pressed {
       pls.velocity -= move_spd * delta_time * right_vec
    }
    if is.right_pressed {
        pls.velocity += move_spd * delta_time * right_vec
    }
    if is.up_pressed {
        pls.velocity += move_spd * delta_time * fwd_vec
    }
    if is.down_pressed {
        pls.velocity -= move_spd * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        pls.velocity += move_spd * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        pls.velocity += move_spd * delta_time * is.vert_axis * fwd_vec
    }

    // register jump button pressed
    if is.z_pressed && !pls.jump_held {
        pls.jump_pressed_time = f32(elapsed_time)
    }

    // clamp xz velocity
    clamped_xz := la.clamp_length(pls.velocity.xz, MAX_PLAYER_SPEED)
    pls.velocity.xz = math.lerp(pls.velocity.xz, clamped_xz, f32(0.05))
    pls.velocity.y = math.clamp(pls.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply ground friction
    if pls.contact_state.state == .ON_GROUND && !got_dir_input {
        pls.velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity
    if pls.contact_state.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(pls.contact_state.contact_ray)
        grav_force := GRAV
        if pls.contact_state.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if pls.contact_state.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if pls.contact_state.state == .ON_WALL || pls.contact_state.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        pls.velocity += down * grav_force * delta_time
    }

    // bunny hop
    can_bunny_hop := f32(elapsed_time) - pls.last_dash > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := pls.contact_state.state != .IN_AIR && math.abs(pls.contact_state.touch_time - pls.jump_pressed_time) < BUNNY_WINDOW
    if got_bunny_hop_input && can_bunny_hop {
        pls.can_press_dash = true
        // pls.bunny_hop_y = pls.position.y
        pls.contact_state.state = .IN_AIR
        pls.velocity.y = GROUND_BUNNY_V_SPEED
        if la.length(pls.velocity.xz) > MIN_BUNNY_XZ_VEL {
            pls.velocity.xz += la.normalize(pls.velocity.xz) * GROUND_BUNNY_H_SPEED
        }

        pls.crunch_pt = pls.position
        pls.crunch_time = f32(elapsed_time)
        pls.last_dash = f32(elapsed_time)

        proj_mat :=  construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{pls.crunch_pt.x, pls.crunch_pt.y, pls.crunch_pt.z, 1})
        pls.screen_crunch_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
        bg_crunch_pt := cs.position + la.normalize0(pls.position - cs.position) * 10000.0;
        append(&pls.crunch_pts, [4]f32{bg_crunch_pt.x, bg_crunch_pt.y, bg_crunch_pt.z, pls.crunch_time})
    }

    // check for jump
    pressed_jump := is.z_pressed && pls.can_press_jump
    ground_jumped := pressed_jump && (pls.contact_state.state == .ON_GROUND || (f32(elapsed_time) - pls.contact_state.left_ground < COYOTE_TIME))
    slope_jumped := pressed_jump && (pls.contact_state.state == .ON_SLOPE || (f32(elapsed_time) - pls.contact_state.left_slope < COYOTE_TIME))
    wall_jumped := pressed_jump && (pls.contact_state.state == .ON_WALL || (f32(elapsed_time) - pls.contact_state.left_wall < COYOTE_TIME))

    // handle normal jump
    if ground_jumped {
        pls.velocity.y = P_JUMP_SPEED
        pls.contact_state.state = .IN_AIR

    // handle slope jump
    } else if slope_jumped {
        pls.velocity += -la.normalize(pls.contact_state.contact_ray) * SLOPE_JUMP_FORCE
        pls.velocity.y = SLOPE_V_JUMP_FORCE
        pls.contact_state.state = .IN_AIR

    // handle wall jump
    } else if wall_jumped {
        pls.velocity.y = P_JUMP_SPEED
        pls.velocity += -pls.contact_state.contact_ray * WALL_JUMP_FORCE 
        pls.contact_state.state = .IN_AIR
    }

    // set target particle displacement on jump
    if ground_jumped || slope_jumped || wall_jumped {
        pls.can_press_jump = false
        pls.tgt_particle_displacement = pls.velocity
    }

    // lerp current particle displacement toward target particle displacement
    pls.particle_displacement = la.lerp(pls.particle_displacement, pls.tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
    if !(pls.contact_state.state == .ON_GROUND) {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, pls.velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }

    // start dash 
    pressed_dash := is.x_pressed && pls.can_press_dash
    if pressed_dash && pls.velocity != 0 {
        pls.can_press_dash = false
        pls.dashing = true
        pls.dash_start_pos = pls.position
        dash_input := input_dir == 0 ? la.normalize0(pls.velocity.xz) : input_dir
        pls.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        pls.dash_end_pos = pls.position + DASH_DIST * pls.dash_dir
        pls.dash_time = f32(elapsed_time)
    }

    //end dash
    hit_surface := pls.contact_state.state == .ON_WALL || grounded
    dash_expired := f32(elapsed_time) > pls.dash_time + DASH_LEN
    if pls.dashing && (hit_surface || dash_expired){
        pls.dash_end_time = f32(elapsed_time)
        pls.dashing = false
        pls.velocity = la.normalize(pls.dash_end_pos - pls.dash_start_pos) * DASH_SPD
        pls.position = pls.dash_end_pos
    }
     
    // during dash
    if pls.dashing {
        pls.velocity = 0
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        pls.position = pls.dash_start_pos + dash_delta * dash_t; //pls.dash_start_pos + dash_delta * dash_t
    }


    // bunny hop time dilation
    // if pls.state != .ON_GROUND && f32(elapsed_time) - pls.crunch_time < 1000 {
    //     if pls.position.y > pls.bunny_hop_y {
    //         fact := abs(pls.velocity.y) / GROUND_BUNNY_V_SPEED
    //         ts.time_mult = clamp(fact * fact * 4.5, 1.15, 1.5)
    //     } else {
    //         ts.time_mult = f32(math.lerp(ts.time_mult, 1, f32(0.05)))
    //     }
    //
    // } else {
    //     ts.time_mult = f32(math.lerp(ts.time_mult, 1, f32(0.05)))
    // }

    // debounce jump/dash input
    if !pls.can_press_jump {
        pls.can_press_jump = !is.z_pressed && grounded || pls.contact_state.state == .ON_WALL
    }
    if !pls.can_press_dash {
        pls.can_press_dash = !is.x_pressed && pls.contact_state.state == .ON_GROUND
    }

    // lerp spike compression
    if pls.contact_state.state == .ON_GROUND {
        pls.spike_compression = math.lerp(pls.spike_compression, 0.35, 0.15) 
    } else {
        pls.spike_compression = math.lerp(pls.spike_compression, 1.1, 0.15) 
    }

    // handle reset level
    if is.r_pressed {
        pls.position = INIT_PLAYER_POS
        pls.velocity = [3]f32 {0, 0, 0}
        for &lg in lgs.entities {
            lg.crack_time = 0;
        } 
    }

    pls.prev_position = pls.position
    pls.jump_held = is.z_pressed


    // ========================================
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // ========================================
    new_contact_state, new_position, new_velocity, collision_ids := apply_velocity(
        pls.contact_state,
        pls.position,
        pls.velocity,
        lgs.entities[:],
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    );
    defer delete(collision_ids)

    if pls.dashing {
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        new_position = pls.dash_start_pos + dash_delta * dash_t
    }

    pls.contact_state = new_contact_state
    pls.position = new_position
    pls.velocity = new_velocity

    cs^ = updated_camera_state(cs^, pls.position)

    new_crunch_pts := updated_crunch_pts(pls.crunch_pts[:], elapsed_time)
    delete(pls.crunch_pts)
    pls.crunch_pts = new_crunch_pts

    pls.anim_angle = math.lerp(pls.anim_angle, math.atan2(pls.velocity.x, -pls.velocity.z), f32(0.1))

    for id in collision_ids {
        lg := &lgs.entities[id]
        lg.crack_time = lg.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.crack_time
    }

    // ts := updated_time_state(pls^, ts^, elapsed_time)
}

// updated_time_mult :: proc(pls: Player_State, elapsed_time: f32, current_time_mult: f32) -> f32 {
//     if pls.state != .ON_GROUND && elapsed_time - pls.crunch_time < 1000 {
//         fact := abs(pls.bunny_hop_y) / GROUND_BUNNY_V_SPEED
//         return (clamp(fact * fact * 4.5, 1.15, 1.5))
//     }
//     return math.lerp(current_time_mult, 1, f32(0.05))
// } 

// updated_time_state :: proc(pls: Player_State, ts: Time_State, elapsed_time: f32) -> Time_State {
//     ts := ts
//     ts.time_mult = updated_time_mult(pls, elapsed_time, ts.time_mult)
//     return ts
// }

