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
    on_surface := grounded || pls.contact_state.state == .ON_WALL

    new_contact_state := pls.contact_state

    new_velocity := pls.velocity

    did_dash := is.x_pressed && pls.can_press_dash && new_velocity != 0
    can_press_dash := updated_can_press_dash(pls.dash_hop_debounce_t, did_dash, pls.can_press_dash, new_contact_state, is, pls.jump_pressed_time, elapsed_time)

    can_bunny_hop := f32(elapsed_time) - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := new_contact_state.state != .IN_AIR && math.abs(pls.contact_state.touch_time - pls.jump_pressed_time) < BUNNY_WINDOW
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
    new_velocity = apply_dash_to_velocity(pls^, new_velocity, elapsed_time)
    new_velocity = apply_restart_to_velocity(is, new_velocity)


    new_dash_hop_debounce_t := updated_dash_hop_debounce_t(pls.dash_hop_debounce_t, did_bunny_hop, elapsed_time)
    new_screen_crunch_pt := updated_screen_crunch_pt(pls.screen_crunch_pt, did_bunny_hop, cs^, new_crunch_pt)

    // handle normal jump
    jumped := ground_jumped || slope_jumped || wall_jumped || did_bunny_hop

    new_contact_state.state = jumped ? .IN_AIR : new_contact_state.state

    new_can_press_jump := updated_can_press_jump(pls.can_press_jump, jumped, is, on_surface)

    // set target particle displacement on jump
    new_tgt_particle_displacement := updated_tgt_particle_displacement(jumped, pls.tgt_particle_displacement, new_velocity, pls.contact_state.state) 

    new_dash_state := updated_dash_state(pls^, did_dash, input_dir, elapsed_time)
    pls.dash_state = new_dash_state

    pls.dashing = updated_dashing(pls.dashing, did_dash, pls.contact_state.state, pls.dash_state.dash_time, elapsed_time)

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

    new_position = apply_dash_to_position(new_position, pls.dash_state.dash_start_pos, pls.dash_state.dash_end_pos, pls.dashing, pls.dash_state.dash_time, elapsed_time) 
    new_position = apply_restart_to_position(is, new_position)

    cs^ = updated_camera_state(cs^, new_position)

    pls.anim_angle = math.lerp(pls.anim_angle, math.atan2(new_velocity.x, -new_velocity.z), f32(0.1))

    for id in collision_ids {
        lg := &lgs.entities[id]
        lg.crack_time = lg.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.crack_time
    }

    new_trail := updated_trail_buffer(new_position, pls.trail)

    pls.prev_trail_sample = pls.trail_sample
    pls.trail = new_trail
    pls.trail_sample = updated_trail_sample(new_trail)

    pls.jump_pressed_time = updated_jump_pressed_time(pls.jump_pressed_time, is, pls.jump_held, elapsed_time) 
    pls.spike_compression = updated_spike_compression(pls.spike_compression, new_contact_state.state)
    pls.contact_state = new_contact_state
    pls.position = new_position
    pls.velocity = new_velocity
    pls.can_press_dash = can_press_dash
    pls.crunch_pt = new_crunch_pt
    pls.crunch_time = new_crunch_time
    pls.dash_hop_debounce_t = new_dash_hop_debounce_t
    pls.screen_crunch_pt = new_screen_crunch_pt
    pls.can_press_jump = new_can_press_jump
    pls.tgt_particle_displacement = new_tgt_particle_displacement
    pls.particle_displacement = la.lerp(pls.particle_displacement, new_tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
    pls.prev_position = pls.position
    pls.jump_held = is.z_pressed

    new_crunch_pts := updated_crunch_pts(pls.crunch_pts[:], elapsed_time, new_position, cs^, did_bunny_hop, new_crunch_time)
    new_lgs := apply_restart_to_lgs(is, lgs.entities)
    dynamic_array_swap(&pls.crunch_pts, &new_crunch_pts)
    dynamic_soa_swap(&lgs.entities, &new_lgs)

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

