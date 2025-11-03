package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    new_ts := ts^
    cts := pls.contact_state

    // ==========================
    // EXTRAPOLATE STATE TRIGGERS
    // ==========================

    // get directional input data
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

    got_dir_input := is.up_pressed || is.down_pressed || is.left_pressed || is.right_pressed || is.hor_axis != 0 || is.vert_axis != 0
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

    // apply directional input to velocity
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

    // clamp velocity to max speed
    clamped_velocity_xz := la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED) 
    new_velocity.xz = math.lerp(new_velocity.xz, clamped_velocity_xz, f32(0.9))
    new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply friction to velocity 
    if cts.state == .ON_GROUND && !got_dir_input {
        new_velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity to velocity
    if cts.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        grav_force := GRAV
        if cts.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if cts.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if cts.state == .ON_WALL || cts.state == .ON_SLOPE {
            down -= la.dot(normalized_contact_ray, down) * normalized_contact_ray
        }
        new_velocity += down * grav_force * delta_time
    }

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

    // apply dash to velocity
    if pls.dash_state.dashing {
        new_velocity = pls.dash_state.dash_dir * DASH_SPD
    }

    // apply slide to velocity
    if pls.slide_state.sliding {
        new_velocity = pls.slide_state.slide_dir * (len(szs.intersected) > 0 ? SLIDE_SPD * 2 : SLIDE_SPD) 
    }

    // apply restart to velocity
    if is.r_pressed {
        new_velocity = 0
    }

    new_contact_state := pls.contact_state

    // apply jump to player state
    if !pls.slide_state.sliding && jumped {
        new_contact_state.state = .IN_AIR
    }

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

    // handle restart player position
    if is.r_pressed {
        new_position = INIT_PLAYER_POS
    }

    // ========================================
    // UPDATE COLLISION-DEPENDENT STATE
    // ========================================
    // apply bounce to velocity
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            new_normalized_contact_ray := la.normalize(collision_adjusted_contact_state.contact_ray)
            bounced_velocity_dir := la.normalize(collision_adjusted_velocity) - new_normalized_contact_ray
            collision_adjusted_velocity = bounced_velocity_dir * BOUNCE_VELOCITY
        }
    }

    // add bunny hop and bounce to time mult
    new_time_mult := math.lerp(ts.time_mult, f32(1.0), f32(0.05))
    if bunny_hopped {
        new_time_mult = 1.75
    }
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            new_time_mult = 1.75
        }
    }

    // update dash state
    new_dash_state := pls.dash_state
    if pls.dash_state.dashing {
        new_dash_state.dash_total += delta_time * 1000.0
    }
    dash_activated := is.x_pressed && pls.dash_state.can_dash
    can_dash := (!on_surface && collision_adjusted_velocity != 0 &&
                 elapsed_time > pls.hurt_t + DAMAGE_LEN && !pls.slide_state.sliding)
    hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN
    dash_expired := pls.dash_state.dash_total > DASH_LEN
    if dash_activated && can_dash {
        dash_input := input_dir
        if dash_input == 0 {
            dash_input = la.normalize0(collision_adjusted_velocity.xz)
        }
        new_dash_dir := [3]f32{dash_input.x, 0, dash_input.y}
        new_dash_state = {
            dashing = true,
            dash_start_pos = new_position,
            dash_dir = new_dash_dir,
            dash_end_pos = new_position + DASH_DIST * new_dash_dir,
            dash_time = elapsed_time,
            dash_total = 0,
            can_dash = false
        }
    } else {
        if hurt || on_surface || dash_expired {
            new_dash_state.dashing = false
            new_dash_state.dash_total = 0
        }         
        if !pls.dash_state.can_dash {
            state := new_contact_state.state
            touched_ground:= state == .ON_GROUND || state == .ON_SLOPE || bunny_hopped
            new_dash_state.can_dash = !pls.dash_state.dashing && touched_ground
        }
    }

    new_pls := pls^

    // update slide state
    new_slide_state := pls.slide_state
    can_slide := on_surface && pls.slide_state.can_slide && collision_adjusted_velocity != 0
    if pls.slide_state.sliding {
        new_slide_state.slide_total += delta_time * 1000.0
    }
    if is.x_pressed && can_slide {
        surface_normal := la.normalize0(la.cross(new_contact_state.ground_x, new_contact_state.ground_z))
        slide_input := [3]f32{input_dir.x, 0, input_dir.y}
        if slide_input == 0 {
            slide_input = la.normalize0(collision_adjusted_velocity)
        }
        new_slide_dir := la.normalize0(slide_input - la.dot(slide_input, surface_normal) * surface_normal)

        new_slide_state.sliding = true
        new_slide_state.can_slide = false
        new_slide_state.slide_time = elapsed_time
        new_slide_state.mid_slide_time = elapsed_time
        new_slide_state.slide_start_pos = new_position
        new_slide_state.slide_total = 0
        new_slide_state.slide_dir = new_slide_dir
    } else {
        slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
        slide_ended := !on_surface || pls.slide_state.slide_total - slide_off > SLIDE_LEN
        slide_can_refresh := pls.slide_state.slide_end_time + SLIDE_COOLDOWN < elapsed_time
        if pls.slide_state.sliding && len(szs.intersected) > 0 {
            new_slide_state.mid_slide_time = elapsed_time
        }
        if pls.slide_state.sliding && slide_ended {
            new_slide_state.sliding = false
            new_slide_state.slide_end_time = elapsed_time
            new_slide_state.slide_total = 0
        }
        if !pls.slide_state.can_slide && !pls.slide_state.sliding && slide_can_refresh {
            new_slide_state.can_slide = true
        }
    }
    
    // update hurt_t
    new_hurt_t := pls.hurt_t
    for id in collision_ids {
        attr := lgs[id].attributes
        dash_req_satisfied := new_dash_state.dashing && .Dash_Breakable in attr
        slide_req_satisfied := new_slide_state.sliding && .Slide_Zone in attr
        if .Hazardous in attr && !(dash_req_satisfied || slide_req_satisfied) {
            new_hurt_t = elapsed_time
        }
    }

    // update broke_t
    new_broke_t := pls.broke_t
    if new_dash_state.dashing {
        for id in collision_ids {
            if .Hazardous in lgs[id].attributes {
                new_broke_t = elapsed_time
            }
        }
    }

    // update crunch_time
    new_crunch_time := bunny_hopped ? elapsed_time : pls.crunch_time

    // update screen_splashes
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

    // update particle displacement
    new_tgt_particle_displacement := pls.tgt_particle_displacement
    if jumped {
        new_tgt_particle_displacement = new_velocity
    }
    if new_contact_state.state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, new_velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    new_particle_displacement := la.lerp(pls.particle_displacement, new_tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)

    // ==========================
    // NEW STUFF PUSHED TO BOTTOM
    // ==========================
    new_pls.velocity = collision_adjusted_velocity
    new_pls.prev_position = pls.position
    new_pls.position = new_position
    new_pls.contact_state = collision_adjusted_contact_state

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

    new_pls.dash_state = new_dash_state
    new_pls.slide_state = new_slide_state

    new_pls.hurt_t = new_hurt_t
    new_pls.broke_t = new_broke_t

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
    new_pls.particle_displacement = new_particle_displacement

    new_ts.time_mult = new_time_mult 

    // ====================================
    // ASSIGN NEW LGS, CAMERA, PLAYER STATE
    // ====================================
    delete(pls.screen_splashes)

    // update level geometry
    new_lgs := soa_copy(lgs^)
    if is.r_pressed {
        for &lg in new_lgs {
            lg.shatter_data.crack_time = 0
            lg.shatter_data.smash_time = 0
        }
    }

    if bunny_hopped {
        last_touched := collision_adjusted_contact_state.last_touched
        new_lgs[last_touched].shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collision_ids {
        lg := &new_lgs[id]
        if .Dash_Breakable in lg.attributes && new_dash_state.dashing {
            lg.shatter_data.smash_time = lg.shatter_data.smash_time == 0.0 ? elapsed_time : lg.shatter_data.smash_time 
            lg.shatter_data.smash_dir = la.normalize(collision_adjusted_velocity)
            lg.shatter_data.smash_pos = new_position
        } else if .Slide_Zone in lg.attributes && new_slide_state.sliding {
            // do nothing
        } else if .Breakable in lg.attributes {
            lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.shatter_data.crack_time
        } else if .Crackable in lg.attributes {
            lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.shatter_data.crack_time
        }
    }

    // update slide zones state
    new_szs_intersected := make(map[int]struct{})
    for sz in szs.entities {
        if lgs[sz.id].shatter_data.crack_time != 0 {
            continue
        }
        if hit, _ := sphere_obb_intersection(sz, new_position, PLAYER_SPHERE_RADIUS); hit {
            new_szs_intersected[sz.id] = {}
        }
    }

    new_szs_entities := dynamic_soa_copy(szs.entities)
    for &sz in new_szs_entities {
        if sz.id in new_szs_intersected {
            sz.transparency_t = clamp(sz.transparency_t - 5.0 * delta_time, 0.1, 0.5)
        } else {
            sz.transparency_t = clamp(sz.transparency_t + 5.0 * delta_time, 0.1, 0.5)
        }
    }

    for &sz in szs.entities {
        new_lgs[sz.id].transparency = sz.transparency_t
    }

    soa_swap(lgs, new_lgs)
    dynamic_soa_swap(&szs.entities, new_szs_entities)
    set_swap(&szs.intersected, new_szs_intersected)

    cs^ = updated_camera_state(cs^, new_position)
    pls^ = new_pls
    ts^ = new_ts
}

