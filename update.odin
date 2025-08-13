package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, elapsed_time: f32, delta_time: f32) {
    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================
    new_pls := pls^

    new_velocity := pls.velocity
    new_velocity = apply_directional_input_to_velocity(pls^, is, new_velocity, delta_time)
    new_velocity = clamp_horizontal_velocity_to_max_speed(new_velocity)
    new_velocity = apply_friction_to_velocity(pls^, is, new_velocity, delta_time)
    new_velocity = apply_gravity_to_velocity(pls^, new_velocity, delta_time)
    new_velocity = apply_jumps_to_velocity(pls^, is, new_velocity, elapsed_time)
    new_velocity = apply_dash_to_velocity(pls^, new_velocity, elapsed_time)
    new_velocity = apply_slide_to_velocity(pls^, new_velocity, elapsed_time)
    new_velocity = apply_restart_to_velocity(is, new_velocity)

    new_contact_state := pls.contact_state
    new_contact_state.state = apply_jump_to_player_state(pls^, is, elapsed_time)

    // ========================================
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // ========================================
    collision_adjusted_contact_state, new_position, collision_adjusted_velocity, collision_ids := apply_velocity(
        new_contact_state,
        pls.position,
        new_velocity,
        lgs.entities[:],
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    ); defer delete(collision_ids)

    new_position = apply_dash_to_position(pls^, new_position, elapsed_time) 
    new_position = apply_slide_to_position(pls^, new_position, elapsed_time) 
    new_position = apply_restart_to_position(is, new_position)

    // ========================================
    // APPLY UPDATED VALUES TO NEW PLAYER STATE
    // ========================================
    new_pls.velocity = collision_adjusted_velocity
    new_pls.prev_position = pls.position
    new_pls.position = new_position
    new_pls.contact_state = collision_adjusted_contact_state

    new_pls.prev_trail_sample = pls.trail_sample
    new_pls.jump_held = is.z_pressed

    new_pls.trail_sample              = updated_trail_sample(pls^)
    new_pls.trail                     = updated_trail_buffer(pls^)
    new_pls.jump_pressed_time         = updated_jump_pressed_time(pls^, is, elapsed_time) 
    new_pls.spike_compression         = updated_spike_compression(pls^)
    new_pls.crunch_time               = updated_crunch_time(pls^, elapsed_time)
    new_pls.dash_hop_debounce_t       = updated_dash_hop_debounce_t(pls^, elapsed_time)
    new_pls.crunch_pt                 = updated_crunch_pt(pls^, elapsed_time)
    new_pls.screen_crunch_pt          = updated_screen_crunch_pt(pls^, cs^, elapsed_time)
    new_pls.can_press_jump            = updated_can_press_jump(pls^, is, elapsed_time)
    new_pls.tgt_particle_displacement = updated_tgt_particle_displacement(pls^, is, elapsed_time)
    new_pls.particle_displacement     = updated_particle_displacement(pls^) 
    new_pls.dash_state                = updated_dash_state(pls^, is, elapsed_time)
    new_pls.slide_state               = updated_slide_state(pls^, is, elapsed_time) 

    new_crunch_pts := updated_crunch_pts(pls^, cs^, elapsed_time)
    dynamic_array_swap(&new_pls.crunch_pts, &new_crunch_pts)

    new_lgs := apply_restart_to_lgs(is, lgs.entities)
    new_lgs = apply_collisions_to_lgs(new_lgs, collision_ids, elapsed_time) 
    new_lgs = apply_bunny_hop_to_lgs(new_lgs, pls^, elapsed_time)
    dynamic_soa_swap(&lgs.entities, new_lgs)

    cs^ = updated_camera_state(cs^, new_position)

    pls^ = new_pls
}

