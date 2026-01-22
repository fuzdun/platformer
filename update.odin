package main

import "core:math"
import "core:fmt"
import "core:slice"
import la "core:math/linalg"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import tim "core:time"
import rnd "core:math/rand"

INFINITE_HOP :: false


game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: ^Physics_State, rs: ^Render_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    cts := pls.contact_state

    // #####################################################
    // EXTRAPOLATE STATE
    // #####################################################

    // directional input
    // -------------------------------------------

    checkpointed := pls.position.y < -100

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

    small_hopped := jump_pressed_surface_touch_time_diff < BUNNY_WINDOW || 
        (
            jump_pressed_slide_end_time_diff < BUNNY_WINDOW &&
            time_since_jump_pressed < BUNNY_WINDOW
        )
 
    got_bunny_hop_input := on_surface && pls.spin_state.spinning

    new_dash_hop_debounce_t := pls.dash_hop_debounce_t

    bunny_hopped := elapsed_time - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE && got_bunny_hop_input && (pls.hops_remaining > 0 || INFINITE_HOP)
    if bunny_hopped || small_hopped {
        new_jump_pressed_time = 0
        new_dash_hop_debounce_t = elapsed_time
    }

    should_jump := is.z_pressed && pls.can_press_jump || bunny_hopped || small_hopped

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
    got_fwd_input := la.dot(la.normalize0(new_velocity.xz), input_dir) > 0.80
    grounded := cts.state == .ON_GROUND || cts.state == .ON_SLOPE
    right_vec := grounded ? pls.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? pls.ground_z : [3]f32{0, 0, -1}
    if !(elapsed_time < pls.hurt_t + DAMAGE_LEN) {
        move_spd := SLOW_ACCEL
        if cts.state == .ON_SLOPE {
            // move_spd = SLOPE_SPEED
        } else if cts.state == .IN_AIR {
            if pls.spin_state.spinning {
                // move_spd = AIR_SPIN_ACCEL
            } else {
                // move_spd = AIR_ACCEL
            }
        }
        if got_fwd_input {
            flat_speed := la.length(new_velocity.xz)
            if flat_speed > FAST_CUTOFF {
                move_spd = FAST_ACCEL

            } else if flat_speed > MED_CUTOFF {
                move_spd = MED_ACCEL
            }
        }
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

    // apply directional input to dash direction
    // -------------------------------------------
    if pls.dash_state.dashing {
        pls.dash_state.dash_dir = la.lerp(pls.dash_state.dash_dir, [3]f32{input_dir.x, 0, input_dir.y}, 0.05)
    }

    // clamp velocity to max speed
    // -------------------------------------------
    clamped_velocity_xz: [2]f32 = 0.0
    if got_fwd_input {
        clamped_velocity_xz = la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED) 
        new_velocity.xz = math.lerp(new_velocity.xz, clamped_velocity_xz, f32(0.01))
    } else {
        clamped_velocity_xz = la.clamp_length(new_velocity.xz, FAST_CUTOFF) 
        new_velocity.xz = math.lerp(new_velocity.xz, clamped_velocity_xz, f32(0.1))
    }
    new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply friction to velocity 
    // -------------------------------------------
    // if cts.state == .ON_GROUND && !got_dir_input {
    if !got_dir_input {
        if la.length(pls.velocity.xz) > FAST_CUTOFF {
            new_velocity *= math.pow(FAST_FRICTION, delta_time)
        } else if !on_surface {
            new_velocity *= math.pow(IDLE_FRICTION, delta_time)
        }
    } else if on_surface {
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
        new_velocity = pls.dash_state.dash_dir * pls.dash_state.dash_spd
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
        new_velocity += -normalized_contact_ray * SLOPE_JUMP_FORCE * (small_hopped ? 0.25 : 1.0)
        new_velocity.y = SLOPE_V_JUMP_FORCE
    } else if wall_jumped {
        new_velocity.y = P_JUMP_SPEED
        new_velocity += -normalized_contact_ray * WALL_JUMP_FORCE 
    }
    if bunny_hopped {
        if ground_jumped {
            new_velocity.y = GROUND_BUNNY_V_SPEED - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_VARIANCE

        }
        new_velocity.xz += la.normalize0(new_velocity.xz) * GROUND_BUNNY_H_SPEED
    } else if small_hopped && ground_jumped {
        new_velocity.y = SMALL_HOP_V_SPEED
    }


    // apply restart to velocity
    // -------------------------------------------
    if is.r_pressed  {
        new_velocity = [3]f32{0, 0, 0}
    }

    if checkpointed  {
        new_velocity = [3]f32{0, 0, -40}
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
    
    // physics_map_start := tim.now()
    physics_map := build_physics_map(lgs^, phs.level_colliders, elapsed_time)

    spin_particle_collisions := get_particle_collisions(rs.player_spin_particles, physics_map)
    for spc in spin_particle_collisions {
        particle := &rs.player_spin_particles.particles.values[spc.id]
        particle_info := &rs.player_spin_particles.particle_info[spc.id]
        particle.xyz -= particle_info.vel * FIXED_DELTA_TIME
        particle_info.vel -= la.dot(spc.normal, particle_info.vel) * spc.normal * 1.5
    }

    collision_adjusted_cts, new_position, collision_adjusted_velocity, collision_ids, contact_ids := apply_velocity(
        new_cts,
        pls.position,
        new_velocity,
        pls.dash_state.dashing,
        pls.slide_state.sliding,
        lgs^,
        physics_map,
        elapsed_time,
        delta_time
    );

    // fmt.println(tim.since(physics_map_start))
    
    // fmt.println(len(phs.static_collider_vertices))

    // get_particle_collision(rs.player_spin_particles.values[:], rs.player_spin_particle_info.values[:], lgs^, phs.level_colliders, phs.static_collider_vertices, delta_time)

    // handle restart player position
    // -------------------------------------------
    if is.r_pressed {
        new_position = INIT_PLAYER_POS
    }

    if checkpointed {
        new_position = INIT_PLAYER_POS - [3]f32{0, 0, f32(CHUNK_DEPTH * pls.current_sector)}
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
            new_normalized_contact_ray := la.normalize0(collision_adjusted_cts.contact_ray)
            bounced_velocity_dir := la.normalize0(collision_adjusted_velocity) - new_normalized_contact_ray
            collision_adjusted_velocity = bounced_velocity_dir * BOUNCE_VELOCITY
            collision_adjusted_cts.state = .IN_AIR
            
        }
    }

    new_time_mult := ts.time_mult
    if new_velocity.y < 0 || on_surface {
        new_time_mult = math.lerp(ts.time_mult, f32(1.0), f32(0.08))
    } else {
        new_time_mult = math.lerp(ts.time_mult, f32(1.0), f32(0.04))
    }
    if bunny_hopped {
        new_time_mult = BUNNY_HOP_TIME_MULT - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_TIME_VARIANCE
    }
    bounced := false
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            new_time_mult = 1.5
            bounced = true
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
            can_dash = false,
            dash_spd = clamp(la.length(collision_adjusted_velocity.xz) * 1.5, MIN_DASH_SPD, MAX_DASH_SPD)
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

    if bounced {
        new_dash_state.can_dash = true
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
        slide_ended := (!on_surface && !(len(szs.intersected) > 0)) || pls.slide_state.slide_total - slide_off > SLIDE_LEN
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

    // update spin state
    // -------------------------------------------
    new_spin_state := pls.spin_state
    // note that this is dependent on begnning of frame contact state
    if new_dash_state.dashing {
        new_spin_state.spinning = false
        new_spin_state.spin_amt = 0
    } else {
        if is.c_pressed && !on_surface && (pls.hops_remaining > 0 || INFINITE_HOP) {
            if !new_spin_state.spinning {
                new_spin_state.spinning = true
                new_spin_state.spin_dir = la.normalize0(collision_adjusted_velocity.xz) 
            } else {
                new_spin_state.spin_dir = la.lerp(new_spin_state.spin_dir, input_dir, 0.50)
                new_spin_state.spin_amt = min(1.0, new_spin_state.spin_amt + 1.5 * delta_time)
            }

        } else {
            if on_surface {
                new_spin_state.spin_amt = 0
            } else {
                new_spin_state.spin_amt = max(0, new_spin_state.spin_amt - 3.0 * delta_time) 
            }
            if new_spin_state.spin_amt == 0 {
                new_spin_state.spinning = false
            }
        }
    }


    // update hops
    // -------------------------------------------
    new_hops_remaining := pls.hops_remaining
    if bunny_hopped {
        new_hops_remaining -= 1
    }
    new_hops_recharge := pls.hops_recharge
    new_hops_recharge += 0.40 * delta_time * pls.intensity
    if new_hops_recharge >= 1 {
        new_hops_recharge -= 1.0
        new_hops_remaining = min(3, new_hops_remaining + 1)
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
        // proj_mat := construct_camera_matrix(cs^, 0)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{
            new_crunch_pt.x,
            new_crunch_pt.y,
            new_crunch_pt.z,
            1
        })
        new_screen_ripple_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    }

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


    new_score := pls.score
    new_score += int(pls.intensity * pls.intensity * 10.0)

    new_intensity := pls.intensity
    flat_speed := la.length(collision_adjusted_velocity.xz)
    tgt_intensity := clamp((flat_speed - INTENSITY_MOD_MIN_SPD) / (INTENSITY_MOD_MAX_SPD - INTENSITY_MOD_MIN_SPD), 0, 1)
    if tgt_intensity > new_intensity {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.006))
    } else {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.016))
    }

    new_time_remaining := pls.time_remaining
    new_time_remaining = max(0, new_time_remaining - delta_time)
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

    new_sector := pls.current_sector
    new_checkpoint_t := pls.last_checkpoint_t
    if -new_position.z > f32(CHUNK_DEPTH * (pls.current_sector + CHECKPOINT_SIZE)) {
        new_sector += CHECKPOINT_SIZE
        new_time_remaining += 3.0
        new_checkpoint_t = elapsed_time 
    }

    if is.r_pressed || checkpointed {
        new_hops_remaining = 0
        new_hops_recharge = 0
    }

    if is.r_pressed {
        new_sector = 0
        new_time_remaining = TIME_LIMIT
        new_score = 0
    }

    if new_time_remaining == 0 {
        new_position = [3]f32{5000, 5000, 5000}
        collision_adjusted_velocity = 0
        new_intensity = 0
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
    pls.spin_state                = new_spin_state
    pls.hurt_t                    = new_hurt_t
    pls.broke_t                   = new_broke_t
    pls.can_press_jump            = new_can_press_jump
    pls.dash_hop_debounce_t       = new_dash_hop_debounce_t
    pls.spike_compression         = new_spike_compression
    pls.screen_ripple_pt          = new_screen_ripple_pt
    pls.ground_x                  = new_ground_x
    pls.ground_z                  = new_ground_z
    pls.intensity                 = new_intensity
    pls.hops_recharge             = new_hops_recharge
    pls.hops_remaining            = new_hops_remaining
    pls.score                     = new_score
    pls.time_remaining            = new_time_remaining
    pls.current_sector            = new_sector
    pls.last_checkpoint_t         = new_checkpoint_t

    // screen splashes---------------------
    idx := 0
    for _ in 0 ..<len(pls.screen_splashes) {
        splash := pls.screen_splashes[idx]
        if elapsed_time - splash[3] > 10000 {
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
    if len(pls.screen_splashes) > 5 {
        ordered_remove(&pls.screen_splashes, 0);
    }

    // #####################################################
    // MUTATE LEVEL GEOMETRY
    // #####################################################

    if is.r_pressed || checkpointed {
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
            sz.transparency_t = clamp(sz.transparency_t - 5.0 * delta_time, 0.1, 1.0)
        } else {
            sz.transparency_t = clamp(sz.transparency_t + 5.0 * delta_time, 0.1, 1.0)
        }
    }

    surface_ortho1 := la.vector3_orthogonal(normalized_contact_ray)
    surface_ortho2 := la.cross(normalized_contact_ray, surface_ortho1)

    player_flat_vel := la.normalize0([3]f32{collision_adjusted_velocity.x, 0, collision_adjusted_velocity.z})
    player_flat_vel_ortho := la.cross(player_flat_vel, [3]f32{0, 1, 0})

    if pls.dash_state.dashing {
        // for idx in 0..<10 {
        //     spawn_angle := rnd.float32() * math.PI * 2.0
        //     spawn_vector := math.sin(spawn_angle) * player_flat_vel_ortho + math.cos(spawn_angle) * [3]f32{0, 1, 0} 
        //     particle_info: Particle_Info = {
        //         (spawn_vector * 20.0 * rnd.float32() + 0.2) + player_flat_vel * DASH_SPD * 0.5,
        //         1.2,
        //         f32(elapsed_time),
        //         (rnd.float32() * 800) + 3000
        //     }
        //     spawn_pos := pls.position.xyz + la.normalize0([3]f32{spawn_vector.x, 0.1, spawn_vector.z}) * 0.5
        //     rs.player_spin_particles.particle_info[rs.player_spin_particles.particles.insert_at] = particle_info
        //     ring_buffer_push(&rs.player_spin_particles.particles, Particle{spawn_pos.x, spawn_pos.y, spawn_pos.z, 0})
        // }
    }

    if bunny_hopped || small_hopped {
        particle_count := small_hopped ? 200 : 1500
        for idx in 0..<particle_count {
            spawn_angle := rnd.float32() * math.PI * 2.0
            spawn_vector := (math.sin(spawn_angle) * surface_ortho1 + math.cos(spawn_angle) * surface_ortho2 - normalized_contact_ray * (rnd.float32() * 0.5 + 0.25)) * 2.5
            particle_info: Particle_Info = {
                spawn_vector * 50.0 * rnd.float32() + 0.2,
                1.2,
                f32(elapsed_time),
                (rnd.float32() * 800) + 3000
            }
            spawn_pos := pls.position.xyz + la.normalize0([3]f32{spawn_vector.x, 0.1, spawn_vector.z}) * 0.5
            rs.player_spin_particles.particle_info[rs.player_spin_particles.particles.insert_at] = particle_info
            ring_buffer_push(&rs.player_spin_particles.particles, Particle{spawn_pos.x, spawn_pos.y, spawn_pos.z, 0})
        }
    }
    particle_count := rs.player_spin_particles.particles.len
    if particle_count > 0 {
        pp := rs.player_spin_particles.particles.values[:particle_count]
        pi := rs.player_spin_particles.particle_info[:particle_count]
        for p_idx in 0..<particle_count {
            pp[p_idx].xyz += pi[p_idx].vel * delta_time
            part := pi[p_idx] 
            pi[p_idx].vel += {0, -75, 0 } * delta_time
            sz_fact := clamp((f32(elapsed_time) - part.time) / part.len, 0, 1)
            pp[p_idx].w = part.max_size * (1.0 - sz_fact * sz_fact * sz_fact)
        }
        sorted_pp := make([][4]f32, particle_count, context.temp_allocator)
        copy_slice(sorted_pp, pp)
        // context.user_ptr = &cs.position
        // z_sort := proc(a: [4]f32, b: [4]f32) -> bool {
        //     cam_pos := (cast(^[3]f32) context.user_ptr)^
        //     return la.length2(a.xyz - cam_pos) > la.length2(b.xyz - cam_pos)
        // }

        buffer_size: i32
        gl.BindBuffer(gl.COPY_READ_BUFFER, rs.trail_particle_vbo)
        gl.GetBufferParameteriv(gl.COPY_READ_BUFFER, gl.BUFFER_SIZE, &buffer_size)
        gl.BindBuffer(gl.COPY_WRITE_BUFFER, rs.prev_trail_particle_vbo)
        gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, 0, 0, int(buffer_size))
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.trail_particle_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(sorted_pp[0]) * particle_count, &sorted_pp[0])

        particle_velocities := rs.player_spin_particles.particle_info.vel
        gl.BindBuffer(gl.COPY_READ_BUFFER, rs.trail_particle_velocity_vbo)
        gl.GetBufferParameteriv(gl.COPY_READ_BUFFER, gl.BUFFER_SIZE, &buffer_size)
        gl.BindBuffer(gl.COPY_WRITE_BUFFER, rs.prev_trail_particle_velocity_vbo)
        gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, 0, 0, int(buffer_size))
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.trail_particle_velocity_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(particle_velocities[0]) * particle_count, &particle_velocities[0])
    }


    // #####################################################
    // MUTATE TIME STATE
    // #####################################################

    ts.time_mult = new_time_mult 


    // #####################################################
    // MUTATE CAMERA STATE
    // #####################################################

    cs.prev_position = cs.position
    cs.prev_target = cs.target
    camera_mode := on_surface ? GROUND_CAMERA : AERIAL_CAMERA
    pos_lerp := la.length(collision_adjusted_velocity.xz) > FAST_CUTOFF ? camera_mode.high_speed_pos_lerp : camera_mode.pos_lerp
    new_pos_tgt_y := new_position.y + camera_mode.pos_offset.y
    new_pos_tgt_z := new_position.z + camera_mode.pos_offset.z
    new_pos_tgt_x := new_position.x + camera_mode.pos_offset.x
    new_pos_tgt : [3]f32 = {new_pos_tgt_x, new_pos_tgt_y, new_pos_tgt_z}
    cs.position = math.lerp(cs.position, new_pos_tgt, f32(pos_lerp))

    new_target := new_position
    cs.target.y = math.lerp(cs.target.y, new_target.y + camera_mode.tgt_y_offset, camera_mode.y_angle_lerp)
    cs.target.x = math.lerp(cs.target.x, new_target.x, camera_mode.x_angle_lerp)
    cs.target.z = math.lerp(cs.target.z, new_target.z, camera_mode.z_angle_lerp)

    fov_mod := MAX_FOV_MOD * pls.intensity//get_intensity_mod(la.length(collision_adjusted_velocity.xz))
    cs.fov = math.lerp(cs.fov, FOV + fov_mod, f32(0.1))

    if is.r_pressed || checkpointed {
        cs.position = new_position + camera_mode.pos_offset
        cs.target = new_target + [3]f32{0, camera_mode.tgt_y_offset, 0}
    }
}

