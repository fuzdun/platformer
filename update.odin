package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: ^Physics_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    cts := pls.contact_state

    // #####################################################
    // EXTRAPOLATE STATE
    // #####################################################

    // directional input
    // -------------------------------------------
    input_x: f32 = 0.0
    input_z: f32 = 0.0
    if is.left_pressed do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed do input_z -= 1
    if is.down_pressed do input_z += 1
    input_dir: [2]f32
    if is.hor_axis != 0 || is.vert_axis != 0 {
        input_dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    } else {
        input_dir = la.normalize0([2]f32{input_x, input_z})
    }
    got_dir_input := input_dir != 0

    // surface contact
    // -------------------------------------------
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL
    normalized_contact_ray := la.normalize(cts.contact_ray) 

    // jump
    // -------------------------------------------
    new_jump_pressed_time := pls.jump_pressed_time
    if (is.z_pressed && !pls.jump_held) {
        new_jump_pressed_time = elapsed_time
    }

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
    new_dash_hop_debounce_t := pls.dash_hop_debounce_t
    bunny_hopped := elapsed_time - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE && got_bunny_hop_input
    if bunny_hopped {
        new_jump_pressed_time = 0
        new_dash_hop_debounce_t = elapsed_time
    }

    should_jump := is.z_pressed && pls.can_press_jump || bunny_hopped

    ground_jump_coyote_time_active := elapsed_time - cts.left_ground < COYOTE_TIME
    slope_jump_coyote_time_active  := elapsed_time - cts.left_slope  < COYOTE_TIME
    wall_jump_coyote_time_active   := elapsed_time - cts.left_wall   < COYOTE_TIME

    ground_jumped := should_jump && (cts.state == .ON_GROUND || ground_jump_coyote_time_active)
    slope_jumped  := should_jump && (cts.state == .ON_SLOPE  || slope_jump_coyote_time_active) 
    wall_jumped   := should_jump && (cts.state == .ON_WALL   || wall_jump_coyote_time_active)

    jumped := ground_jumped || slope_jumped || wall_jumped

    new_can_press_jump := jumped ? false : pls.can_press_jump || !is.z_pressed && on_surface 

    // wall stick
    // -------------------------------------------
    new_wall_detach_held_t := pls.wall_detach_held_t
    if cts.state == .ON_WALL {
        if la.dot([3]f32{input_dir.x, 0, input_dir.y}, normalized_contact_ray) >= 0 {
            new_wall_detach_held_t = 0 
        } else {
            new_wall_detach_held_t += delta_time * 1000.0
        }
        
    } else {
        new_wall_detach_held_t = 0
    }

    // #####################################################
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // #####################################################

    new_velocity := pls.velocity

    // apply directional input to velocity
    // -------------------------------------------
    if !(elapsed_time < pls.hurt_t + DAMAGE_LEN) {
        move_spd := P_ACCEL
        if cts.state == .ON_SLOPE {
            move_spd = SLOPE_SPEED
        } else if cts.state == .IN_AIR {
            move_spd = AIR_SPEED
        }
        grounded := cts.state == .ON_GROUND || cts.state == .ON_SLOPE
        right_vec := grounded ? pls.ground_x : [3]f32{1, 0, 0}
        fwd_vec := grounded ? pls.ground_z : [3]f32{0, 0, -1}
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
    // -------------------------------------------
    clamped_velocity_xz := la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED) 
    new_velocity.xz = math.lerp(new_velocity.xz, clamped_velocity_xz, f32(0.9))
    new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply friction to velocity 
    // -------------------------------------------
    if cts.state == .ON_GROUND && !got_dir_input {
        new_velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity to velocity
    // -------------------------------------------
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
    // -------------------------------------------
    if cts.state == .ON_WALL && new_wall_detach_held_t < WALL_DETACH_LEN {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    } 

    // apply dash to velocity
    // -------------------------------------------
    if pls.dash_state.dashing {
        new_velocity = pls.dash_state.dash_dir * DASH_SPD
    }

    // apply slide to velocity
    // -------------------------------------------
    if pls.slide_state.sliding {
        new_velocity = pls.slide_state.slide_dir * (len(szs.intersected) > 0 ? SLIDE_SPD * 2 : SLIDE_SPD) 
    }

    // apply slope to velocity
    // -------------------------------------------
    if cts.state == .ON_GROUND || cts.state == .ON_SLOPE {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    }

    // apply jump to velocity
    // -------------------------------------------
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


    // apply restart to velocity
    // -------------------------------------------
    if is.r_pressed {
        new_velocity = 0
    }

    new_cts := pls.contact_state

    // apply jump to player state
    // -------------------------------------------
    if !pls.slide_state.sliding && jumped {
        new_cts.state = .IN_AIR
    }

    // #####################################################
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // #####################################################

    collision_adjusted_cts, new_position, collision_adjusted_velocity, collision_ids, contact_ids := apply_velocity(
        new_cts,
        pls.position,
        new_velocity,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        lgs^,
        phs.level_colliders,
        phs.static_collider_vertices,
        elapsed_time,
        delta_time
    );

    // handle restart player position
    // -------------------------------------------
    if is.r_pressed {
        new_position = INIT_PLAYER_POS
    }

    // #####################################################
    // UPDATE COLLISION-DEPENDENT STATE
    // #####################################################

    // update ground movement vectors
    // -------------------------------------------
    new_ground_x := pls.ground_x
    new_ground_z := pls.ground_z
    if collision_adjusted_cts.state == .ON_GROUND || collision_adjusted_cts.state == .ON_SLOPE {
        contact_ray := collision_adjusted_cts.contact_ray
        x := [3]f32{1, 0, 0}
        z := [3]f32{0, 0, -1}
        new_ground_x = la.normalize0(x + la.dot(x, contact_ray) * contact_ray)
        new_ground_z = la.normalize0(z + la.dot(z, contact_ray) * contact_ray)
    }

    // apply bounce to velocity
    // -------------------------------------------
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            new_normalized_contact_ray := la.normalize(collision_adjusted_cts.contact_ray)
            bounced_velocity_dir := la.normalize(collision_adjusted_velocity) - new_normalized_contact_ray
            collision_adjusted_velocity = bounced_velocity_dir * BOUNCE_VELOCITY
            collision_adjusted_cts.state = .IN_AIR
        }
    }

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
    // -------------------------------------------
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
            state := collision_adjusted_cts.state
            touched_ground:= state == .ON_GROUND || state == .ON_SLOPE || bunny_hopped
            new_dash_state.can_dash = !pls.dash_state.dashing && touched_ground
        }
    }

    // update slide state
    // -------------------------------------------
    new_slide_state := pls.slide_state
    can_slide := on_surface && pls.slide_state.can_slide && collision_adjusted_velocity != 0
    if pls.slide_state.sliding {
        new_slide_state.slide_total += delta_time * 1000.0
    }
    if is.x_pressed && can_slide {
        surface_normal := la.normalize0(la.cross(new_ground_x, new_ground_z))
        slide_input := [3]f32{input_dir.x, 0, input_dir.y}
        if slide_input == 0 {
            slide_input = la.normalize0(collision_adjusted_velocity)
        }
        new_slide_dir := la.normalize0(slide_input + la.dot(slide_input, surface_normal) * surface_normal)

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
    // -------------------------------------------
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
    // -------------------------------------------
    new_broke_t := pls.broke_t
    if new_dash_state.dashing {
        for id in collision_ids {
            if .Hazardous in lgs[id].attributes {
                new_broke_t = elapsed_time
            }
        }
    }

    // update crunch_time
    // -------------------------------------------
    new_crunch_time := bunny_hopped ? elapsed_time : pls.crunch_time

    // update crunch pt
    // -------------------------------------------
    new_crunch_pt := pls.crunch_pt
    if bunny_hopped {
        new_crunch_pt = pls.position
    }

    // update screen ripple
    // -------------------------------------------
    new_screen_ripple_pt := pls.screen_ripple_pt
    if bunny_hopped {
        proj_mat := construct_camera_matrix(cs^)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{
            new_crunch_pt.x,
            new_crunch_pt.y,
            new_crunch_pt.z,
            1
        })
        new_screen_ripple_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    }

    // update screen_splashes
    // -------------------------------------------
    // new_screen_splashes := make([dynamic][4]f32)
    // for splash in pls.screen_splashes {
    //     append(&new_screen_splashes, splash)
    // }


    // update particle displacement
    // -------------------------------------------
    new_tgt_particle_displacement := pls.tgt_particle_displacement
    if jumped {
        new_tgt_particle_displacement = new_velocity
    }
    if collision_adjusted_cts.state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, new_velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    new_particle_displacement := la.lerp(pls.particle_displacement, new_tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)

    // update spike compression
    // -------------------------------------------
    new_spike_compression := pls.spike_compression
    if cts.state == .ON_GROUND {
        new_spike_compression = math.lerp(pls.spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } else {
        new_spike_compression = math.lerp(pls.spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    }

    when MOVE {
        // test moving geometry
        // ---------------------------------------
        for _, lg_idx in lgs {
            move_geometry(lgs, phs, &new_position, collision_adjusted_cts, lg_idx)
        }
    }

    // #####################################################
    // MUTATE PLAYER STATE 
    // #####################################################

    // prev frame values
    // -------------------------------------------
    pls.prev_position = pls.position
    pls.prev_trail_sample = pls.trail_sample
    pls.jump_held = is.z_pressed
    pls.trail_sample = {
        ring_buffer_at(pls.trail, -4),
        ring_buffer_at(pls.trail, -8),
        ring_buffer_at(pls.trail, -12),
    }

    // overwrite state properties
    //--------------------------------------------
    ring_buffer_push(&pls.trail, new_position)

    pls.velocity                  = collision_adjusted_velocity
    pls.position                  = new_position
    pls.contact_state             = collision_adjusted_cts
    pls.jump_pressed_time         = new_jump_pressed_time
    pls.wall_detach_held_t        = new_wall_detach_held_t
    pls.crunch_time               = new_crunch_time

    pls.crunch_pt                 = new_crunch_pt
    pls.tgt_particle_displacement = new_tgt_particle_displacement
    pls.particle_displacement     = new_particle_displacement
    pls.dash_state                = new_dash_state
    pls.slide_state               = new_slide_state
    pls.hurt_t                    = new_hurt_t
    pls.broke_t                   = new_broke_t
    pls.can_press_jump            = new_can_press_jump
    pls.dash_hop_debounce_t       = new_dash_hop_debounce_t
    pls.spike_compression         = new_spike_compression
    pls.screen_ripple_pt          = new_screen_ripple_pt
    pls.ground_x                  = new_ground_x
    pls.ground_z                  = new_ground_z

    idx := 0
    for _ in 0 ..<len(pls.screen_splashes) {
        splash := pls.screen_splashes[idx]
        if elapsed_time - splash[3] > 3000 {
            ordered_remove(&pls.screen_splashes, idx)
        } else {
            idx += 1
        }
    }
    if bunny_hopped {
        new_splash := cs.position + la.normalize0(new_position - cs.position) * 10000.0;
        append(&pls.screen_splashes, [4]f32{
            new_splash.x,
            new_splash.y,
            new_splash.z,
            new_crunch_time
        })
    }

    // delete(pls.screen_splashes)
    // pls.screen_splashes           = new_screen_splashes

    // #####################################################
    // MUTATE LEVEL GEOMETRY
    // #####################################################

    if is.r_pressed {
        for &lg in lgs {
            lg.shatter_data.crack_time = 0
            lg.shatter_data.smash_time = 0
        }
    }

    if bunny_hopped {
        last_touched := collision_adjusted_cts.last_touched
        lgs[last_touched].shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collision_ids {
        lg := &lgs[id]
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

    for &sz in szs.entities {
        lgs[sz.id].transparency = sz.transparency_t
    }

    // #####################################################
    // MUTATE SLIDE ZONES
    // #####################################################

    clear(&szs.intersected)
    for sz in szs.entities {
        if lgs[sz.id].shatter_data.crack_time != 0 {
            continue
        }
        if hit, _ := sphere_obb_intersection(sz, new_position, PLAYER_SPHERE_RADIUS); hit {
            szs.intersected[sz.id] = {}
        }
    }

    for &sz in szs.entities {
        if sz.id in szs.intersected {
            sz.transparency_t = clamp(sz.transparency_t - 5.0 * delta_time, 0.1, 0.5)
        } else {
            sz.transparency_t = clamp(sz.transparency_t + 5.0 * delta_time, 0.1, 0.5)
        }
    }

    // #####################################################
    // MUTATE TIME STATE
    // #####################################################

    ts.time_mult = new_time_mult 

    cs.prev_position = cs.position
    cs.prev_target = cs.target
    tgt_y := new_position.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := new_position.z + CAMERA_PLAYER_Z_OFFSET
    tgt_x := new_position.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(CAMERA_POS_LERP))
    cs.target.x = math.lerp(cs.target.x, new_position.x, f32(CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, new_position.y, f32(CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, new_position.z, f32(CAMERA_Z_LERP))
}

