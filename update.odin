package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    new_pls := pls^
    cts := pls.contact_state

    // ======================
    // EXTRAPOLATE STATE INFO
    // ======================
    did_bunny_hop := did_bunny_hop(
        pls.dash_hop_debounce_t, cts.touch_time,
        pls.jump_pressed_time, pls.slide_state.slide_end_time,
        elapsed_time
    )

    pressed_jump := pressed_jump(
        did_bunny_hop, is.z_pressed,
        pls.can_press_jump, elapsed_time
    )

    ground_jumped := ground_jumped(
        cts.state, pressed_jump,
        cts.left_ground, elapsed_time
    )

    slope_jumped := slope_jumped(
        cts.state, pressed_jump,
        cts.left_slope, elapsed_time
    )

    wall_jumped := wall_jumped(
        cts.state, pressed_jump,
        cts.left_wall, elapsed_time
    )

    jumped := jumped(
        ground_jumped, slope_jumped,
        wall_jumped, did_bunny_hop,
        elapsed_time
    )

    // ==================================
    // UPDATE INTRAFRAME-INDEPENDENT STATE
    // ==================================
    new_pls.prev_trail_sample = pls.trail_sample
    new_pls.jump_held = is.z_pressed

    new_pls.trail_sample = updated_trail_sample(pls.trail)
    new_pls.trail = updated_trail_buffer(pls.trail, pls.position)

    new_pls.jump_pressed_time = updated_jump_pressed_time(
        did_bunny_hop,
        is.z_pressed,
        pls.jump_held,
        pls.jump_pressed_time,
        elapsed_time
    ) 

    new_pls.spike_compression = updated_spike_compression(
        pls.spike_compression,
        cts.state
    )

    new_pls.crunch_time = updated_crunch_time(
        pls.crunch_time,
        did_bunny_hop,
        elapsed_time
    )

    new_pls.dash_hop_debounce_t = updated_dash_hop_debounce_t(
        pls.dash_hop_debounce_t,
        did_bunny_hop,
        elapsed_time
    )

    new_pls.crunch_pt = updated_crunch_pt(
        pls.crunch_pt,
        pls.position,
        did_bunny_hop,
        elapsed_time
    )

    new_pls.screen_crunch_pt = updated_screen_crunch_pt(
        pls.screen_crunch_pt,
        pls.position,
        pls.crunch_pt,
        did_bunny_hop,
        cs^,
        elapsed_time
    )

    new_pls.can_press_jump = updated_can_press_jump(
        pls.can_press_jump,
        cts.state,
        jumped,
        is.z_pressed,
        elapsed_time 
    )

    new_pls.tgt_particle_displacement = updated_tgt_particle_displacement(
        pls.tgt_particle_displacement,
        cts.state,
        pls.velocity,
        jumped,
        elapsed_time
    )

    new_pls.particle_displacement = updated_particle_displacement(
        pls.particle_displacement,
        pls.tgt_particle_displacement
    ) 

    new_crunch_pts := updated_crunch_pts(
        pls.crunch_pts[:],
        pls.crunch_time,
        did_bunny_hop,
        cs^,
        pls.position,
        elapsed_time
    )

    dynamic_array_swap(&new_pls.crunch_pts, &new_crunch_pts)

    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================
    new_velocity := pls.velocity

    new_velocity = apply_directional_input_to_velocity(
        is.left_pressed, is.right_pressed,
        is.up_pressed, is.down_pressed,
        is.hor_axis, is.vert_axis,
        pls.hurt_t, cts.state,
        cts.ground_x, cts.ground_z,
        pls.velocity, elapsed_time,
        delta_time
    )

    new_velocity = clamp_horizontal_velocity_to_max_speed(new_velocity)

    new_velocity = apply_friction_to_velocity(
        cts.state, is.up_pressed,
        is.down_pressed, is.left_pressed,
        is.right_pressed, is.hor_axis,
        is.vert_axis, new_velocity, delta_time
    )

    new_velocity = apply_gravity_to_velocity(
        cts.state, cts.contact_ray,
        new_velocity, delta_time
    )

    new_velocity = apply_jumps_to_velocity(
        new_velocity, did_bunny_hop,
        ground_jumped, slope_jumped,
        wall_jumped, cts.contact_ray,
        elapsed_time
    )

    new_velocity = apply_dash_to_velocity(
        new_velocity, cts.state,
        pls.dash_state, elapsed_time
    )

    new_velocity = apply_slide_to_velocity(
        new_velocity, cts.state,
        pls.slide_state, elapsed_time
    )

    new_velocity = apply_restart_to_velocity(
        new_velocity, is.r_pressed
    )

    new_contact_state := pls.contact_state

    new_contact_state.state = apply_jump_to_player_state(
        new_contact_state.state,
        pls.slide_state.sliding,
        jumped, elapsed_time
    )

    // ========================================
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // ========================================
    collision_adjusted_contact_state, new_position, collision_adjusted_velocity, collision_ids := apply_velocity(
        new_contact_state,
        pls.position,
        new_velocity,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        lgs.entities[:],
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    ); defer delete(collision_ids)

    new_position = apply_restart_to_position(is, new_position)

    // ========================================
    // UPDATE COLLISION-DEPENDENT STATE
    // ========================================
    new_pls.velocity = collision_adjusted_velocity
    new_pls.prev_position = pls.position
    new_pls.position = new_position
    new_pls.contact_state = collision_adjusted_contact_state

    new_pls.dash_state = updated_dash_state(
        pls.dash_state,
        cts.state,
        pls.slide_state.sliding,
        pls.hurt_t,
        pls.position,
        pls.velocity,
        is,
        did_bunny_hop,
        collision_ids,
        elapsed_time
    )

    new_pls.slide_state = updated_slide_state(
        pls.slide_state,
        is,
        cts.state,
        pls.position,
        pls.velocity,
        cts.ground_x,
        cts.ground_z,
        collision_ids,
        lgs.entities[:],
        szs.intersected,
        elapsed_time
    )

    new_pls.hurt_t = updated_hurt_t(
        pls.hurt_t,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        collision_ids,
        lgs.entities,
        elapsed_time
    )

    new_pls.broke_t = updated_broke_t(
        pls.broke_t,
        pls.dash_state.dashing,
        collision_ids,
        lgs.entities,
        elapsed_time
    )

    new_lgs := dynamic_soa_copy(lgs.entities)

    new_lgs = apply_restart_to_lgs(is, new_lgs)

    new_lgs = apply_bunny_hop_to_lgs(
        new_lgs,
        did_bunny_hop,
        cts.last_touched,
        elapsed_time
    )

    new_lgs = apply_collisions_to_lgs(
        new_lgs,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        pls.position,
        pls.velocity,
        collision_ids,
        elapsed_time
    ) 

    new_lgs = apply_transparency_to_lgs(new_lgs, szs.entities[:], elapsed_time)

    // set_swap(&szs.last_intersected, szs.intersected)
    delete(szs.intersected)
    szs.intersected = get_slide_zone_intersections(pls.position, szs^)

    new_szs := dynamic_soa_copy(szs.entities)
    new_szs = apply_transparency_to_szs(new_szs, szs.intersected, delta_time)

    // ====================================
    // ASSIGN NEW LGS, CAMERA, PLAYER STATE
    // ====================================
    dynamic_soa_swap(&lgs.entities, new_lgs)
    dynamic_soa_swap(&szs.entities, new_szs)

    cs^ = updated_camera_state(cs^, new_position)
    pls^ = new_pls
}

