package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    new_pls := pls^
    new_ts := ts^
    cts := pls.contact_state

    // ==========================
    // EXTRAPOLATE STATE TRIGGERS
    // ==========================
    input_dir := input_dir(is)
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL
    normalized_contact_ray := la.normalize(cts.contact_ray) 

    new_jump_pressed_time := pls.jump_pressed_time
    if (is.z_pressed && !pls.jump_held) {
        new_jump_pressed_time = elapsed_time
    }

    bunny_hop_debounce_expired := elapsed_time - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE
    jump_pressed_surface_touch_time_diff := abs(cts.touch_time - new_jump_pressed_time)
    jump_pressed_slide_end_time_diff := abs(pls.slide_state.slide_end_time - new_jump_pressed_time)
    time_since_jump_pressed := elapsed_time - new_jump_pressed_time 
    got_bunny_hop_input := (
        jump_pressed_surface_touch_time_diff < BUNNY_WINDOW ||
        (
            jump_pressed_slide_end_time_diff < BUNNY_WINDOW &&
            time_since_jump_pressed < BUNNY_WINDOW
        )
    )
    bunny_hopped := bunny_hop_debounce_expired && got_bunny_hop_input
    if bunny_hopped {
        new_jump_pressed_time = 0
    }

    should_jump := is.z_pressed && pls.can_press_jump || bunny_hopped

    ground_jump_coyote_time_active := elapsed_time - cts.left_ground < COYOTE_TIME
    slope_jump_coyote_time_active  := elapsed_time - cts.left_slope  < COYOTE_TIME
    wall_jump_coyote_time_active   := elapsed_time - cts.left_wall   < COYOTE_TIME

    ground_jumped := should_jump && (cts.state == .ON_GROUND || ground_jump_coyote_time_active)
    slope_jumped  := should_jump && (cts.state == .ON_SLOPE  || slope_jump_coyote_time_active) 
    wall_jumped   := should_jump && (cts.state == .ON_WALL   || wall_jump_coyote_time_active)

    jumped := ground_jumped || slope_jumped || wall_jumped

    new_wall_detach_held_t := pls.wall_detach_held_t
    if cts.state == .ON_WALL {
        // pressed dir towards wall
        if la.dot([3]f32{input_dir.x, 0, input_dir.y}, normalized_contact_ray) >= 0 {
            new_wall_detach_held_t = 0 
        } else {
            new_wall_detach_held_t += delta_time * 1000.0
        }
        
    } else {
        new_wall_detach_held_t = 0
    }


    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================
    new_velocity := pls.velocity

    dir_input_disabled_by_hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN
    if !dir_input_disabled_by_hurt {
        move_spd := P_ACCEL
        if cts.state == .ON_SLOPE {
            move_spd = SLOPE_SPEED
        } else if cts.state == .IN_AIR {
            move_spd = AIR_SPEED
        }
        grounded := cts.state == .ON_GROUND || cts.state == .ON_SLOPE
        right_vec := grounded ? cts.ground_x : [3]f32{1, 0, 0}
        fwd_vec := grounded ? cts.ground_z : [3]f32{0, 0, -1}
        if is.left_pressed {
            new_velocity -= move_spd * delta_time * right_vec
        }
        if is.right_pressed {
            new_velocity += move_spd * delta_time * right_vec
        }
        if is.up_pressed {
            new_velocity += move_spd * delta_time * fwd_vec
        }
        if is.down_pressed {
            new_velocity -= move_spd * delta_time * fwd_vec
        }
        if is.hor_axis != 0 {
            new_velocity += move_spd * delta_time * is.hor_axis * right_vec
        }
        if is.vert_axis != 0 {
            new_velocity += move_spd * delta_time * is.vert_axis * fwd_vec
        }
    }

    clamped_velocity_xz := la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED) 
    new_velocity.xz = math.lerp(new_velocity.xz, clamped_velocity_xz, f32(0.9))
    new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

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

    // apply wall stick to velocity
    if cts.state == .ON_WALL && new_wall_detach_held_t < WALL_DETACH_LEN {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    } 

    // apply jump to velocity
    if ground_jumped {
        new_velocity.y = P_JUMP_SPEED
    } else if slope_jumped {
        new_velocity += -normalized_contact_ray * SLOPE_JUMP_FORCE
        new_velocity.y = SLOPE_V_JUMP_FORCE
    } else if wall_jumped {
        new_velocity.y = P_JUMP_SPEED
        new_velocity += -normalized_contact_ray * WALL_JUMP_FORCE 
    }
    if bunny_hopped {
        if ground_jumped {
            new_velocity.y = GROUND_BUNNY_V_SPEED
        }
        new_velocity.xz += la.normalize0(new_velocity.xz) * GROUND_BUNNY_H_SPEED
    }

    new_velocity = apply_dash_to_velocity(
        new_velocity, cts.state,
        pls.dash_state, elapsed_time
    )

    new_velocity = apply_slide_to_velocity(
        new_velocity, cts.state,
        pls.slide_state,
        szs.intersected, elapsed_time
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
    collision_adjusted_contact_state, new_position, collision_adjusted_velocity, collision_ids, contact_ids := apply_velocity(
        new_contact_state,
        pls.position,
        new_velocity,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        lgs^,
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    ); defer delete(collision_ids); defer delete(contact_ids)

    new_position = apply_restart_to_position(is, new_position)

    // ========================================
    // UPDATE COLLISION-DEPENDENT STATE
    // ========================================

    collision_adjusted_velocity = apply_bounce_to_velocity(
        collision_adjusted_velocity,
        collision_adjusted_contact_state.contact_ray,
        collision_ids,
        lgs^
    )

    new_pls.velocity = collision_adjusted_velocity

    new_pls.prev_position = pls.position
    new_pls.position = new_position
    new_pls.contact_state = collision_adjusted_contact_state

    new_time_mult := math.lerp(ts.time_mult, f32(1.0), f32(0.05))
    if bunny_hopped {
        new_time_mult = 1.75
    }
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            new_time_mult = 1.75
        }
    }

    new_pls.dash_state = updated_dash_state(
        pls.dash_state,
        cts.state,
        pls.slide_state.sliding,
        pls.hurt_t,
        pls.position,
        pls.velocity,
        is,
        bunny_hopped,
        collision_ids,
        elapsed_time,
        delta_time
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
        lgs^,
        szs.intersected,
        elapsed_time,
        delta_time
    )

    new_pls.hurt_t = updated_hurt_t(
        pls.hurt_t,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        collision_ids,
        lgs^,
        elapsed_time
    )

    new_pls.broke_t = updated_broke_t(
        pls.broke_t,
        pls.dash_state.dashing,
        collision_ids,
        lgs^,
        elapsed_time
    )

    new_lgs := soa_copy(lgs^)

    new_lgs = apply_restart_to_lgs(is, new_lgs)

    new_lgs = apply_bunny_hop_to_lgs(
        new_lgs,
        bunny_hopped,
        collision_adjusted_contact_state.last_touched,
        // contact_ids,
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
    szs.intersected = get_slide_zone_intersections(pls.position, szs^, lgs^)

    new_szs := dynamic_soa_copy(szs.entities)
    new_szs = apply_transparency_to_szs(new_szs, szs.intersected, delta_time)

    new_crunch_time := bunny_hopped ? elapsed_time : pls.crunch_time

    new_screen_splashes := make([dynamic][4]f32)
    for splash in pls.screen_splashes {
        append(&new_screen_splashes, splash)
    }
    idx := 0
    for _ in 0 ..<len(new_screen_splashes) {
        splash := new_screen_splashes[idx]
        if elapsed_time - splash[3] > 3000 {
            ordered_remove(&new_screen_splashes, idx)
        } else {
            idx += 1
        }
    }
    if bunny_hopped {
        new_splash := cs.position + la.normalize0(pls.position - cs.position) * 10000.0;
        append(&new_screen_splashes, [4]f32{
            new_splash.x,
            new_splash.y,
            new_splash.z,
            new_crunch_time
        })
    }

    new_crunch_pt := pls.crunch_pt
    if bunny_hopped {
        new_crunch_pt = pls.position
    }

    new_tgt_particle_displacement := pls.tgt_particle_displacement
    if jumped {
        new_tgt_particle_displacement = new_velocity
    }
    if new_contact_state.state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, new_velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }

    // ==========================
    // NEW STUFF PUSHED TO BOTTOM
    // ==========================
    new_pls.jump_held = is.z_pressed
    new_pls.jump_pressed_time = new_jump_pressed_time
    new_pls.wall_detach_held_t = new_wall_detach_held_t
    new_pls.can_press_jump = jumped ? false :
        pls.can_press_jump || !is.z_pressed && on_surface 

    if bunny_hopped {
        new_pls.dash_hop_debounce_t = elapsed_time
    }

    new_pls.prev_trail_sample = pls.trail_sample

    new_pls.trail_sample = {
        ring_buffer_at(pls.trail, -4),
        ring_buffer_at(pls.trail, -8),
        ring_buffer_at(pls.trail, -12),
    }

    new_pls.trail = ring_buffer_copy(pls.trail)
    ring_buffer_push(&new_pls.trail, [3]f32 {
        pls.position.x,
        pls.position.y,
        pls.position.z
    })

    if cts.state == .ON_GROUND {
        new_pls.spike_compression = math.lerp(new_pls.spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } else {
        new_pls.spike_compression = math.lerp(new_pls.spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    }

    new_pls.crunch_time = new_crunch_time
    new_pls.screen_splashes = new_screen_splashes
    new_pls.crunch_pt = new_crunch_pt


    if bunny_hopped {
        proj_mat := construct_camera_matrix(cs^)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{
            new_crunch_pt.x,
            new_crunch_pt.y,
            new_crunch_pt.z,
            1
        })
        new_pls.screen_ripple_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    }

    new_pls.tgt_particle_displacement = new_tgt_particle_displacement
    new_pls.particle_displacement = la.lerp(pls.particle_displacement, new_tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)

    new_ts.time_mult = new_time_mult 

    // ====================================
    // ASSIGN NEW LGS, CAMERA, PLAYER STATE
    // ====================================
    delete(pls.screen_splashes)
    soa_swap(lgs, new_lgs)
    dynamic_soa_swap(&szs.entities, new_szs)

    cs^ = updated_camera_state(cs^, new_position)
    pls^ = new_pls
    ts^ = new_ts
}

