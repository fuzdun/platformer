package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"

CRACK_DELAY :: 1500
BREAK_DELAY :: 1500


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, elapsed_time: f32, delta_time: f32) {

    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================
    // update trail


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

    grounded := pls.contact_state.state == .ON_GROUND || pls.contact_state.state == .ON_SLOPE


    new_jump_pressed_time := updated_jump_pressed_time(pls.jump_pressed_time, is, pls.jump_held, elapsed_time)

    new_contact_state := pls.contact_state

    new_velocity := pls.velocity

    did_dash := is.x_pressed && pls.can_press_dash && new_velocity != 0
    can_press_dash := updated_can_press_dash(pls.last_dash, did_dash, pls.can_press_dash, new_contact_state, is, new_jump_pressed_time, elapsed_time)

    can_bunny_hop := f32(elapsed_time) - pls.last_dash > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := new_contact_state.state != .IN_AIR && math.abs(pls.contact_state.touch_time - new_jump_pressed_time) < BUNNY_WINDOW
    did_bunny_hop := can_bunny_hop && got_bunny_hop_input

    pressed_jump := is.z_pressed && pls.can_press_jump
    ground_jumped := pressed_jump && (new_contact_state.state == .ON_GROUND || (f32(elapsed_time) - new_contact_state.left_ground < COYOTE_TIME))
    slope_jumped := pressed_jump && (new_contact_state.state == .ON_SLOPE || (f32(elapsed_time) - new_contact_state.left_slope < COYOTE_TIME))
    wall_jumped := pressed_jump && (new_contact_state.state == .ON_WALL || (f32(elapsed_time) - new_contact_state.left_wall < COYOTE_TIME))

    new_crunch_pt := updated_crunch_pt(pls.position, pls.crunch_pt, did_bunny_hop)
    new_crunch_time := updated_crunch_time(did_bunny_hop, pls.crunch_time, elapsed_time)

    new_velocity = apply_directional_input_to_velocity(pls.contact_state, is, new_velocity, move_spd, delta_time)
    new_velocity = clamp_horizontal_velocity_to_max_speed(new_velocity)
    new_velocity = apply_friction_to_velocity(pls.contact_state.state, new_velocity, got_dir_input, delta_time)
    new_velocity = apply_gravity_to_velocity(new_velocity, pls.contact_state, delta_time)
    new_velocity = apply_jumps_to_velocity(new_velocity, did_bunny_hop, ground_jumped, slope_jumped, wall_jumped, new_contact_state.contact_ray)

    if did_bunny_hop {
        new_contact_state.state = .IN_AIR
        pls.last_dash = f32(elapsed_time)

        bg_crunch_pt := cs.position + la.normalize0(pls.position - cs.position) * 10000.0;
        append(&pls.crunch_pts, [4]f32{bg_crunch_pt.x, bg_crunch_pt.y, bg_crunch_pt.z, pls.crunch_time})
        proj_mat :=  construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{new_crunch_pt.x, new_crunch_pt.y, new_crunch_pt.z, 1})
        pls.screen_crunch_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    }

    // handle normal jump
    if ground_jumped {
        new_contact_state.state = .IN_AIR

    // handle slope jump
    } else if slope_jumped {
        new_contact_state.state = .IN_AIR

    // handle wall jump
    } else if wall_jumped {
        new_contact_state.state = .IN_AIR
    }

    // set target particle displacement on jump
    if ground_jumped || slope_jumped || wall_jumped {
        pls.can_press_jump = false
        pls.tgt_particle_displacement = new_velocity
    }

    // lerp current particle displacement toward target particle displacement
    pls.particle_displacement = la.lerp(pls.particle_displacement, pls.tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
    if !(new_contact_state.state == .ON_GROUND) {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, new_velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }

    // start dash 
    // pressed_dash := is.x_pressed && pls.can_press_dash
    if did_dash {
        pls.can_press_dash = false
        pls.dashing = true
        pls.dash_start_pos = pls.position
        dash_input := input_dir == 0 ? la.normalize0(new_velocity.xz) : input_dir
        pls.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        pls.dash_end_pos = pls.position + DASH_DIST * pls.dash_dir
        pls.dash_time = f32(elapsed_time)
    }

    //end dash
    hit_surface := new_contact_state.state == .ON_WALL || grounded
    dash_expired := f32(elapsed_time) > pls.dash_time + DASH_LEN
    if pls.dashing && (hit_surface || dash_expired){
        pls.dash_end_time = f32(elapsed_time)
        pls.dashing = false
        new_velocity = la.normalize(pls.dash_end_pos - pls.dash_start_pos) * DASH_SPD
        pls.position = pls.dash_end_pos
    }
     
    // during dash
    if pls.dashing {
        new_velocity = 0
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        pls.position = pls.dash_start_pos + dash_delta * dash_t; //pls.dash_start_pos + dash_delta * dash_t
    }


    // bunny hop time dilation
    // if pls.state != .ON_GROUND && f32(elapsed_time) - pls.crunch_time < 1000 {
    //     if pls.position.y > pls.bunny_hop_y {
    //         fact := abs(new_velocity.y) / GROUND_BUNNY_V_SPEED
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
        pls.can_press_jump = !is.z_pressed && grounded || new_contact_state.state == .ON_WALL
    }

    // if pressed_dash && new_velocity != 0 {
    //     pls.can_press_dash = false
    // }
    //
    // if !pls.can_press_dash {
    //     pls.can_press_dash = !is.x_pressed && pls.contact_state.state == .ON_GROUND
    // }
    //
    // handle reset level
    if is.r_pressed {
        pls.position = INIT_PLAYER_POS
        new_velocity = [3]f32 {0, 0, 0}
        for &lg in lgs.entities {
            lg.crack_time = 0;
        } 
    }

    pls.prev_position = pls.position
    pls.jump_held = is.z_pressed


    // ========================================
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // ========================================
    adjusted_contact_state, new_position, adjusted_velocity, collision_ids := apply_velocity(
        pls.contact_state,
        pls.position,
        new_velocity,
        lgs.entities[:],
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    );
    defer delete(collision_ids)

    new_velocity = adjusted_velocity
    new_contact_state = adjusted_contact_state

    if pls.dashing {
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        new_position = pls.dash_start_pos + dash_delta * dash_t
    }

    cs^ = updated_camera_state(cs^, new_position)

    new_crunch_pts := updated_crunch_pts(pls.crunch_pts[:], elapsed_time)
    delete(pls.crunch_pts)
    pls.crunch_pts = new_crunch_pts

    pls.anim_angle = math.lerp(pls.anim_angle, math.atan2(new_velocity.x, -new_velocity.z), f32(0.1))

    for id in collision_ids {
        lg := &lgs.entities[id]
        lg.crack_time = lg.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.crack_time
    }

    new_trail := updated_trail_buffer(new_position, pls.trail)
    new_trail_sample := updated_trail_sample(new_trail)

    pls.prev_trail_sample = pls.trail_sample
    pls.trail_sample = new_trail_sample
    pls.trail = new_trail
    pls.jump_pressed_time = new_jump_pressed_time 
    pls.spike_compression = updated_spike_compression(pls.spike_compression, new_contact_state.state)
    pls.contact_state = new_contact_state
    pls.position = new_position
    pls.velocity = new_velocity
    pls.can_press_dash = can_press_dash
    pls.crunch_pt = new_crunch_pt
    pls.crunch_time = new_crunch_time

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

