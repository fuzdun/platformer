package main

import "core:math"
import "core:fmt"
import "core:slice"
import la "core:math/linalg"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import tim "core:time"
import rnd "core:math/rand"

INFINITE_HOP :: true

update_player :: proc(
    lgs: ^Level_Geometry_State,
    pls: ^Player_State,
    phs: ^Physics_State,
    rs: ^Render_State,
    cs: ^Camera_State,
    ts: ^Time_State,
    szs: ^Slide_Zone_State,
    triggers: Action_Triggers,
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) {

    // #####################################################
    // PRE VELOCITY
    // #####################################################

    cts := pls.contact_state
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL
    normalized_contact_ray := la.normalize(cts.contact_ray) 

    // spin
    // -------------------------------------------
    new_spin_state := pls.spin_state
    if pls.mode != .Normal || on_surface {
        new_spin_state.spin_amt = 0
    } else {

        // start new spin or lerp spin direction
        // -------------------------------------------
        if triggers.spin && (pls.hops_remaining > 0 || INFINITE_HOP) {
            if new_spin_state.spin_amt == 0 {
                new_spin_state.spin_dir = la.normalize0(pls.velocity.xz) 

            } else {
                new_spin_state.spin_dir = la.lerp(new_spin_state.spin_dir, triggers.move, 0.50)
            }
            new_spin_state.spin_amt = min(1.0, new_spin_state.spin_amt + 1.5 * delta_time)
        } else {
            new_spin_state.spin_amt = max(0, new_spin_state.spin_amt - 3.0 * delta_time) 
        }
    }

    // move speed
    // -------------------------------------------
    move_spd := SLOW_ACCEL
    if cts.state == .ON_SLOPE {
        // move_spd = SLOPE_SPEED
    } else if cts.state == .IN_AIR {
        if new_spin_state.spin_amt > 0 {
            // move_spd = AIR_SPIN_ACCEL
        } else {
            // move_spd = AIR_ACCEL
        }
    }
    if triggers.fwd_move {
        flat_speed := la.length(pls.velocity.xz)
        if flat_speed > FAST_CUTOFF {
            move_spd = FAST_ACCEL

        } else if flat_speed > MED_CUTOFF {
            move_spd = MED_ACCEL
        }
    }

    // other 
    // -------------------------------------------
    is_hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN
    in_slide_zone := len(szs.intersected) > 0
    sent_to_checkpoint := pls.position.y < -100


    // #####################################################
    // MODE
    // #####################################################

    new_mode := pls.mode

    new_jump_enabled := pls.jump_enabled
    new_dash_enabled := pls.dash_enabled
    new_slide_enabled := pls.slide_enabled

    if triggers.jump {
        new_jump_enabled = false
    }

    new_dash_state := pls.dash_state
    new_slide_state := pls.slide_state

    // normal mode 
    // -------------------------------------------
    if pls.mode == .Normal {

        // handle dash activation 
        // -------------------------------------------
        //can_dash := (pls.dash_enabled && cts.state == .IN_AIR && pls.velocity != 0 && !is_hurt)
        //if is.x_pressed && can_dash {
        if triggers.dash {
            new_mode = .Dashing
            dash_input := triggers.move
            if dash_input == 0 {
                dash_input = la.normalize0(pls.velocity.xz)
            }
            new_dash_state.dash_start_pos = pls.position
            new_dash_state.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
            new_dash_state.dash_time = elapsed_time
            new_dash_state.dash_spd = clamp(la.length(pls.velocity.xz) * 1.5, MIN_DASH_SPD, MAX_DASH_SPD)
            new_dash_enabled = false
        }

        // handle slide activation 
        // -------------------------------------------
        //can_slide := on_surface && new_slide_enabled && pls.velocity != 0
        //if is.x_pressed && can_slide {
        if triggers.slide {
            new_mode = .Sliding
            surface_normal := la.normalize0(la.cross(pls.ground_x, pls.ground_z))
            slide_input := [3]f32{triggers.move.x, 0, triggers.move.y}
            if slide_input == 0 {
                slide_input = la.normalize0(pls.velocity)
            }
            new_slide_dir := la.normalize0(slide_input + la.dot(slide_input, surface_normal) * surface_normal)
            new_slide_state.slide_time = elapsed_time
            new_slide_state.mid_slide_time = elapsed_time
            new_slide_state.slide_start_pos = pls.position
            new_slide_state.slide_dir = new_slide_dir
            new_slide_enabled = false
        }

    // dashing mode 
    // -------------------------------------------
    } else if pls.mode == .Dashing {

        // adjust dash direction 
        // -------------------------------------------
        new_dash_state.dash_dir = la.lerp(pls.dash_state.dash_dir, [3]f32{triggers.move.x, 0, triggers.move.y}, 0.03)

        // check for end of dash 
        // -------------------------------------------
        if is_hurt || on_surface || elapsed_time - pls.dash_state.dash_time > DASH_LEN {
            new_mode = .Normal
        }         

    // sliding mode 
    // -------------------------------------------
    } else if pls.mode == .Sliding {

        // update slide offset
        // -------------------------------------------
        if new_mode == .Sliding && len(szs.intersected) > 0 {
            new_slide_state.mid_slide_time = elapsed_time
        }

        // check for end of slide 
        // -------------------------------------------
        time_since_slide_start := elapsed_time - new_slide_state.slide_time
        slide_start_to_zone_exit := new_slide_state.mid_slide_time - new_slide_state.slide_time
        time_since_exit_zone := time_since_slide_start - slide_start_to_zone_exit
        if (!on_surface && len(szs.intersected) == 0) || time_since_exit_zone > SLIDE_LEN {
            new_mode = .Normal
            new_slide_state.slide_end_time = elapsed_time
        }
    }


    // #####################################################
    // VELOCITY
    // #####################################################

    new_velocity := pls.velocity

    if new_mode == .Normal {

        // directional input
        // -------------------------------------------
        if !is_hurt {
            new_velocity.xz += triggers.move * move_spd * delta_time
        }

        // clamp to max
        // -------------------------------------------
        if triggers.fwd_move {
            new_velocity.xz = math.lerp(
                new_velocity.xz,
                la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED),
                f32(0.01)
            )
        } else {
            new_velocity.xz = math.lerp(
                new_velocity.xz,
                la.clamp_length(new_velocity.xz, FAST_CUTOFF),
                f32(0.1)
            )
        }
        new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

        // friction
        // -------------------------------------------
        if triggers.move == 0 {
            if la.length(pls.velocity.xz) > FAST_CUTOFF {
                new_velocity *= math.pow(FAST_FRICTION, delta_time)
            } else if !on_surface {
                new_velocity *= math.pow(IDLE_FRICTION, delta_time)
            } else {
                new_velocity *= math.pow(GROUND_FRICTION, delta_time)
            }
        }

        // gravity
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

        // wall stick
        // -------------------------------------------
        if cts.state == .ON_WALL && triggers.wall_detach_held < WALL_DETACH_LEN {
            new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
        } 

        // jump
        // -------------------------------------------
        if triggers.ground_jump {
            new_velocity.y = P_JUMP_SPEED
        } else if triggers.slope_jump {
            new_velocity += -normalized_contact_ray * SLOPE_JUMP_FORCE * (triggers.small_hop ? 0.25 : 1.0)
            new_velocity.y = SLOPE_V_JUMP_FORCE
        } else if triggers.wall_jump {
            new_velocity.y = P_JUMP_SPEED
            new_velocity += -normalized_contact_ray * WALL_JUMP_FORCE 
        }
        if triggers.bunny_hop {
            if triggers.ground_jump {
                new_velocity.y = GROUND_BUNNY_V_SPEED - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_VARIANCE

            }
            new_velocity.xz += la.normalize0(new_velocity.xz) * GROUND_BUNNY_H_SPEED
        } else if triggers.small_hop && triggers.ground_jump {
            new_velocity.y = SMALL_HOP_V_SPEED
        }

    // set velocity if dashing
    // -------------------------------------------
    } else if new_mode == .Dashing {
        new_velocity = pls.dash_state.dash_dir * pls.dash_state.dash_spd

    // set velocity if sliding 
    // -------------------------------------------
    } else if new_mode == .Sliding {
        new_velocity = pls.slide_state.slide_dir * (in_slide_zone ? SLIDE_SPD * 2 : SLIDE_SPD) 
    }

    //slope adjustment (if no jump)
    //-------------------------------------------
    if (cts.state == .ON_GROUND || cts.state == .ON_SLOPE) && !triggers.jump {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    }

    // if jumped, change to in air state 
    // -------------------------------------------
    new_cts := cts
    if new_mode == .Normal && triggers.jump {
        new_cts.state = .IN_AIR
    }


    // #####################################################
    // APPLY VELOCITY, HANDLE COLLISIONS
    // #####################################################

    collision_adjusted_cts, new_position, collision_adjusted_velocity, collision_ids, contact_ids := apply_velocity(
        new_cts,
        pls.position,
        new_velocity,
        new_mode == .Dashing,
        new_mode == .Sliding,
        lgs^,
        physics_map,
        elapsed_time,
        delta_time
    );


    // #####################################################
    // POST COLLISION 
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

    // update hops
    // -------------------------------------------
    new_hops_remaining := pls.hops_remaining
    if triggers.bunny_hop {
        new_hops_remaining -= 1
    }
    new_hops_recharge := pls.hops_recharge
    new_hops_recharge += 0.40 * delta_time * pls.intensity
    if new_hops_recharge >= 1 {
        new_hops_recharge -= 1.0
        new_hops_remaining = min(3, new_hops_remaining + 1)
    }

    // MOVE THIS!!!!!!!!!
    // update time mult
    // -------------------------------------------
    new_time_mult := ts.time_mult
    if new_velocity.y < 0 || on_surface {
        new_time_mult = math.lerp(ts.time_mult, f32(1.0), f32(0.06))
    } else {
        new_time_mult = math.lerp(ts.time_mult, f32(1.0), f32(0.03))
    }
    if triggers.bunny_hop {
        new_time_mult = BUNNY_HOP_TIME_MULT - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_TIME_VARIANCE
    }

    // handle collision effects
    // -------------------------------------------
    new_hurt_t := pls.hurt_t
    new_broke_t := pls.broke_t

    for id in collision_ids {
        attr := lgs[id].attributes
        dash_req_satisfied := new_mode == .Dashing && .Dash_Breakable in attr
        slide_req_satisfied := new_mode == .Sliding && .Slide_Zone in attr

        if .Hazardous in attr {
            if !(dash_req_satisfied || slide_req_satisfied) {
                new_hurt_t = elapsed_time
            } else {
                new_broke_t = elapsed_time
            }
        }
        if .Bouncy in lgs[id].attributes {
            new_time_mult = 1.5
            new_dash_enabled = true
            break
        }
    }

    // update crunch_time
    // -------------------------------------------
    new_crunch_time := triggers.bunny_hop ? elapsed_time : pls.crunch_time

    // update crunch pt
    // -------------------------------------------
    new_crunch_pt := pls.crunch_pt
    if triggers.bunny_hop {
        new_crunch_pt = pls.position
    }

    // update screen ripple
    // -------------------------------------------
    new_screen_ripple_pt := pls.screen_ripple_pt
    if triggers.bunny_hop {
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
    if triggers.jump {
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
    //if tgt_intensity > new_intensity {
    //    new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.006))
    //} else {
    //    new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.016))
    //}
    if tgt_intensity > new_intensity {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.004))
    } else {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.0010))
    }

    new_time_remaining := pls.time_remaining
    new_time_remaining = max(0, new_time_remaining - delta_time)

    collided_cts := collision_adjusted_cts.state

    new_jump_enabled = new_jump_enabled || !pls.jump_held && collided_cts == .ON_GROUND || collided_cts == .ON_SLOPE 
    new_slide_enabled = new_slide_enabled || pls.slide_state.slide_end_time + SLIDE_COOLDOWN < elapsed_time
    new_dash_enabled = new_dash_enabled || collided_cts == .ON_GROUND || collided_cts == .ON_SLOPE ||
                       triggers.bunny_hop || triggers.small_hop

    // MOVE THIS !!!!!!!!!!!!!!!!!!
    // sector / checkpoints
    // -------------------------------------------
    new_sector := pls.current_sector
    new_checkpoint_t := pls.last_checkpoint_t
    if -new_position.z > f32(CHUNK_DEPTH * (pls.current_sector + CHECKPOINT_SIZE)) {
        new_sector += CHECKPOINT_SIZE
        new_time_remaining += 3.0
        new_checkpoint_t = elapsed_time 
    }


    // MOVE THIS !! (the parts not related to player state)
    // restart / checkpoint / end round overrides
    // -------------------------------------------
    if triggers.restart  {
        collision_adjusted_velocity = [3]f32{0, 0, 0}
        new_position = INIT_PLAYER_POS
        new_sector = 0
        new_time_remaining = TIME_LIMIT
        new_score = 0
    }

    if sent_to_checkpoint {
        collision_adjusted_velocity = [3]f32{0, 0, -40}
        new_position = INIT_PLAYER_POS - [3]f32{0, 0, f32(CHUNK_DEPTH * pls.current_sector)}
    }

    if triggers.restart || sent_to_checkpoint {
        new_hops_remaining = 0
        new_hops_recharge = 0
    }

    if new_time_remaining == 0 {
        new_position = [3]f32{5000, 5000, 5000}
        collision_adjusted_velocity = 0
        new_intensity = 0
    }

    // prevent extra hops
    // -------------------------------------------
    new_last_hop := pls.last_hop
    if triggers.small_hop {
        new_last_hop = triggers.small_hop_time
    }


    // #####################################################
    // MUTATE PLAYER STATE 
    // #####################################################

    // prev frame values
    // -------------------------------------------
    pls.prev_position = pls.position
    pls.prev_trail_sample = pls.trail_sample
    pls.jump_held = triggers.jump_held
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
    pls.mode                      = new_mode
    pls.contact_state             = collision_adjusted_cts
    pls.jump_pressed_time         = triggers.jump_pressed_time
    pls.wall_detach_held_t        = triggers.wall_detach_held
    pls.crunch_time               = new_crunch_time

    pls.crunch_pt                 = new_crunch_pt
    pls.tgt_particle_displacement = new_tgt_particle_displacement
    pls.particle_displacement     = new_particle_displacement
    pls.dash_state                = new_dash_state
    pls.slide_state               = new_slide_state
    pls.spin_state                = new_spin_state
    pls.hurt_t                    = new_hurt_t
    pls.broke_t                   = new_broke_t
    pls.jump_enabled              = new_jump_enabled
    pls.dash_enabled              = new_dash_enabled
    pls.spike_compression         = new_spike_compression
    pls.screen_ripple_pt          = new_screen_ripple_pt
    pls.ground_x                  = new_ground_x
    pls.ground_z                  = new_ground_z
    pls.intensity                 = new_intensity
    pls.hops_recharge             = new_hops_recharge
    pls.hops_remaining            = new_hops_remaining
    pls.last_hop                  = new_last_hop
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
    if triggers.bunny_hop {
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

    if triggers.restart || sent_to_checkpoint {
        for &lg in lgs {
            lg.shatter_data.crack_time = 0
            lg.shatter_data.smash_time = 0
        }
    }

    if triggers.bunny_hop {
       last_touched := collision_adjusted_cts.last_touched
       lgs[last_touched].shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collision_ids {
        lg := &lgs[id]
        if .Dash_Breakable in lg.attributes && new_mode == .Dashing {
            lg.shatter_data.smash_time = lg.shatter_data.smash_time == 0.0 ? elapsed_time : lg.shatter_data.smash_time 
            lg.shatter_data.smash_dir = la.normalize(collision_adjusted_velocity)
            lg.shatter_data.smash_pos = new_position
        } else if .Slide_Zone in lg.attributes && new_mode == .Sliding {
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

    player_flat_vel := la.normalize0([3]f32{collision_adjusted_velocity.x, 0, collision_adjusted_velocity.z})
    player_flat_vel_ortho := la.cross(player_flat_vel, [3]f32{0, 1, 0})


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

    if triggers.restart || sent_to_checkpoint {
        cs.position = new_position + camera_mode.pos_offset
        cs.target = new_target + [3]f32{0, camera_mode.tgt_y_offset, 0}
    }
}

