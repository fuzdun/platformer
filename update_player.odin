package main

import "core:math"
import la "core:math/linalg"

INFINITE_HOP :: true

update_player :: proc(
    lgs: Level_Geometry_State,
    pls: ^Player_State,
    gs: Game_State,
    triggers: Action_Triggers,
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) -> (collisions: Collision_Log) {


    // #####################################################
    // PRE VELOCITY
    // #####################################################

    cts := pls.contact_state
    on_ground := cts.state == .ON_GROUND || cts.state == .ON_SLOPE
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL
    is_hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN
    normalized_contact_ray := la.normalize(cts.contact_ray) 

    // update ground movement vectors
    // -------------------------------------------
    new_ground_x := pls.ground_x
    new_ground_z := pls.ground_z
    if on_ground {
        contact_ray := cts.contact_ray
        x := [3]f32{1, 0, 0}
        z := [3]f32{0, 0, -1}
        new_ground_x = la.normalize0(x + la.dot(x, contact_ray) * contact_ray)
        new_ground_z = la.normalize0(z + la.dot(z, contact_ray) * contact_ray)
    }

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

    // update hops
    // -------------------------------------------
    new_hops_remaining := pls.hops_remaining
    if triggers.bunny_hop {
        new_hops_remaining -= 1
    }
    new_hops_recharge := pls.hops_recharge
    new_hops_recharge += 0.40 * delta_time * gs.intensity
    if new_hops_recharge >= 1 {
        new_hops_recharge -= 1.0
        new_hops_remaining = min(3, new_hops_remaining + 1)
    }


    // #####################################################
    // MODE
    // #####################################################

    new_mode := pls.mode
    new_jump_enabled := triggers.new_jump_enabled
    new_slide_enabled := triggers.new_slide_enabled
    new_dash_enabled := triggers.new_dash_enabled
    new_dash_state := pls.dash_state
    new_slide_state := pls.slide_state

    // normal mode 
    // -------------------------------------------
    if pls.mode == .Normal {
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
        new_dash_state.dash_dir = la.lerp(pls.dash_state.dash_dir, [3]f32{triggers.move.x, 0, triggers.move.y}, 0.03)
        if is_hurt || on_surface || elapsed_time - pls.dash_state.dash_time > DASH_LEN {
            new_mode = .Normal
        }         

    // sliding mode 
    // -------------------------------------------
    } else if pls.mode == .Sliding {
        if new_mode == .Sliding && triggers.slide_zone {
            new_slide_state.mid_slide_time = elapsed_time
        }
        time_since_slide_start := elapsed_time - new_slide_state.slide_time
        slide_start_to_zone_exit := new_slide_state.mid_slide_time - new_slide_state.slide_time
        time_since_exit_zone := time_since_slide_start - slide_start_to_zone_exit
        if (!on_surface && !triggers.slide_zone) || time_since_exit_zone > SLIDE_LEN {
            new_mode = .Normal
            new_slide_state.slide_end_time = elapsed_time
        }
    }

    // prevent extra hops
    // -------------------------------------------
    new_last_small_hop := pls.last_small_hop
    if triggers.small_hop {
        new_last_small_hop = elapsed_time
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
        new_velocity = pls.slide_state.slide_dir * (triggers.slide_zone ? SLIDE_SPD * 2 : SLIDE_SPD) 
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

    collision_adjusted_cts, new_position,
    collision_adjusted_velocity, collision_ids,
    contact_ids, touched_ground := apply_velocity(
        new_cts,
        pls.position,
        new_velocity,
        new_mode == .Dashing,
        new_mode == .Sliding,
        lgs,
        physics_map,
        elapsed_time,
        delta_time
    );
    

    // #####################################################
    // POST COLLISION 
    // #####################################################

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
            new_normalized_contact_ray := la.normalize0(collision_adjusted_cts.contact_ray)
            bounced_velocity_dir := la.normalize0(collision_adjusted_velocity) - new_normalized_contact_ray
            collision_adjusted_velocity = bounced_velocity_dir * BOUNCE_VELOCITY
            collision_adjusted_cts.state = .IN_AIR
            break
        }
    }

    if touched_ground {
        new_dash_enabled = true
    }

    collided_cts := collision_adjusted_cts.state

    // handle checkpoint / restart
    // -------------------------------------------
    if triggers.restart  {
        collision_adjusted_velocity = [3]f32{0, 0, 0}
        new_position = INIT_PLAYER_POS
    }

    if triggers.checkpoint {
        collision_adjusted_velocity = [3]f32{0, 0, -40}
        new_position = INIT_PLAYER_POS - [3]f32{0, 0, f32(CHUNK_DEPTH * gs.current_sector)}
    }

    if triggers.restart || triggers.checkpoint {
        new_hops_remaining = 0
        new_hops_recharge = 0
    }

    // handle round end
    // -------------------------------------------
    if gs.time_remaining == 0 {
        new_position = [3]f32{5000, 5000, 5000}
        collision_adjusted_velocity = 0
    }


    // #####################################################
    // MUTATE STATE 
    // #####################################################

    // prev frame values
    // -------------------------------------------
    pls.prev_position      = pls.position

    // update state values
    // -------------------------------------------
    pls.mode               = new_mode
    pls.velocity           = collision_adjusted_velocity
    pls.position           = new_position
    pls.contact_state      = collision_adjusted_cts
    pls.wall_detach_held_t = triggers.wall_detach_held
    pls.dash_state         = new_dash_state
    pls.slide_state        = new_slide_state
    pls.spin_state         = new_spin_state
    pls.hurt_t             = new_hurt_t
    pls.broke_t            = new_broke_t
    pls.jump_enabled       = new_jump_enabled
    pls.dash_enabled       = new_dash_enabled
    pls.slide_enabled      = new_slide_enabled
    pls.ground_x           = new_ground_x
    pls.ground_z           = new_ground_z
    pls.hops_recharge      = new_hops_recharge
    pls.hops_remaining     = new_hops_remaining
    pls.last_small_hop     = new_last_small_hop

    // move to input update
    pls.jump_pressed_time  = triggers.jump_pressed_time

    // move to input update
    pls.jump_held          = triggers.jump_button_pressed

    return collision_ids
}

