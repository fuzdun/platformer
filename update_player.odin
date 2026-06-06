package main

import "core:math"
import la "core:math/linalg"
import hm "core:container/handle_map"

INFINITE_HOP :: true

GROUND_BASE: f32 : -14.00


update_player :: proc(
    lgs: ^Level_Geometry_State,
    pls: ^Player_State,
    gs: Game_State,
    triggers: Action_Triggers,
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) -> (
    collisions: Collision_Log,
    intersections: map[Handle]struct{}
) {


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

    move_spd := FAST_ACCEL

    new_mode := pls.mode
    new_jump_enabled := triggers.new_jump_enabled


    // #####################################################
    // VELOCITY
    // #####################################################

    new_velocity := pls.velocity

    if !is_hurt {
        // new_velocity.xz += triggers.move * move_spd * delta_time
        new_velocity.x += triggers.move.x * move_spd * delta_time
    }

    // clamp to max
    // -------------------------------------------
    new_velocity.xz = math.lerp(
        new_velocity.xz,
        la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED),
        f32(0.01)
    )

    // friction
    // -------------------------------------------
        if triggers.move == 0 {
            new_velocity *= math.pow(FRICTION, delta_time)
        }

    // wall stick
    // -------------------------------------------
    if cts.state == .ON_WALL && triggers.wall_detach_held < WALL_DETACH_LEN {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    } 

    // jump
    // -------------------------------------------
    // if triggers.ground_jump {
    // if triggers.jump {
    //     new_velocity.y = P_JUMP_SPEED
    // } else if triggers.slope_jump {
    //     new_velocity += -normalized_contact_ray * SLOPE_JUMP_FORCE// * (triggers.small_hop ? 0.25 : 1.0)
    //     new_velocity.y = SLOPE_V_JUMP_FORCE
    // } else if triggers.wall_jump {
    //     new_velocity.y = P_JUMP_SPEED
    //     new_velocity += -normalized_contact_ray * WALL_JUMP_FORCE 
    // }
    // if triggers.bunny_hop {
    //     if triggers.ground_jump {
    //         new_velocity.y = GROUND_BUNNY_V_SPEED * 0.75// - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_VARIANCE
    //
    //     }
    //     new_velocity.xz += la.normalize0(new_velocity.xz) * GROUND_BUNNY_H_SPEED
    // }
    // } else if triggers.small_hop && triggers.ground_jump {
    //     new_velocity.y = SMALL_HOP_V_SPEED
    // }

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

    // new collision logic:
    // - bpm-based arc controls both position and velocity
    // - still use position and velocity to check for collisions mid-jump as usual
    // - at end of jump, velocity should be correct

    next_position: = [3]f32{pls.position.x, GROUND_BASE, 10 -BEAT_SPACE * current_beat_progress}
    new_velocity.z = (next_position.z - pls.position.z) / delta_time

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
    )
    

    // #####################################################
    // POST COLLISION 
    // #####################################################

    // handle collision effects
    // -------------------------------------------
    intersections = make(map[Handle]struct{})
    lg_it := hm.iterator_make(lgs)
    for lg, handle in hm.iterate(&lg_it) {
        if lg.shatter_data.crack_time != 0 {
            continue
        }
        sz_obb := lg_to_obb(lg^)
        if hit, _ := sphere_obb_intersection(sz_obb, pls.position, PLAYER_SPHERE_RADIUS); hit {
            intersections[handle] = {}
        }
    }

    new_hurt_t := pls.hurt_t
    new_broke_t := pls.broke_t
    for id in collision_ids {
        lg := hm.get(lgs, id)            
        attr := lg.attributes
        dash_req_satisfied := new_mode == .Dashing && .Dash_Breakable in attr
        slide_req_satisfied := new_mode == .Sliding && .Slide_Zone in attr

        if .Hazardous in attr {
            if !(dash_req_satisfied || slide_req_satisfied) {
                new_hurt_t = elapsed_time
            } else {
                new_broke_t = elapsed_time
            }
        }
        if .Bouncy in attr {
            new_normalized_contact_ray := la.normalize0(collision_adjusted_cts.contact_ray)
            bounced_velocity_dir := la.normalize0(collision_adjusted_velocity) - new_normalized_contact_ray
            collision_adjusted_velocity = bounced_velocity_dir * BOUNCE_VELOCITY
            collision_adjusted_cts.state = .IN_AIR
            break
        }
    }

    // if touched_ground {
    //     new_dash_enabled = true
    // }

    collided_cts := collision_adjusted_cts.state

    // handle checkpoint / restart
    // -------------------------------------------
    if triggers.restart  {
        collision_adjusted_velocity = [3]f32{0, 0, 0}
        new_position = INIT_PLAYER_POS
    }

    if triggers.checkpoint {
        collision_adjusted_velocity = [3]f32{0, 0, 0}
        // new_position = INIT_PLAYER_POS - [3]f32{0, 0, f32(CHUNK_DEPTH * gs.current_sector)}
        new_position = [3]f32{new_position.x, 25, next_position.z}
    }

    // handle round end
    // -------------------------------------------
    if gs.time_remaining == 0 {
        new_position = [3]f32{5000, 5000, 5000}
        collision_adjusted_velocity = 0
    }

    // interpolated_beat_progress := math.lerp(last_beat_progress, current_beat_progress)

    if triggers.small_hop || triggers.bunny_hop || triggers.jump {
        bpm_jump_start = current_beat_progress
        if triggers.small_hop || triggers.bunny_hop {
            bpm_jump_end = math.round(bpm_jump_start) + TEST_JUMP_BEAT_COUNT
        } else {
            raw_jump_end := current_beat_progress + TEST_JUMP_BEAT_COUNT
            bpm_jump_end = math.lerp(raw_jump_end, math.round(raw_jump_end), f32(0.75))
        }
    }

    if current_beat_progress >= bpm_jump_start && current_beat_progress <= bpm_jump_end {
        jump_midpoint := bpm_jump_end - ((bpm_jump_end - bpm_jump_start) * 0.5)
        arc_len := jump_midpoint - bpm_jump_start
        jump_progress := current_beat_progress - bpm_jump_start
        jump_grav := -(2.0 * TEST_JUMP_HEIGHT) / (arc_len * arc_len)
        jump_init_vel := -jump_grav * arc_len
        new_position.y = GROUND_BASE + jump_init_vel * jump_progress + 0.5 * jump_grav * jump_progress * jump_progress
        collision_adjusted_velocity.yz = new_position.yz - pls.position.yz
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
    pls.hurt_t             = new_hurt_t
    pls.broke_t            = new_broke_t
    pls.jump_enabled       = new_jump_enabled
    pls.ground_x           = new_ground_x
    pls.ground_z           = new_ground_z

    // move to input update
    pls.jump_pressed_time  = triggers.jump_pressed_time

    // move to input update
    pls.jump_held          = triggers.jump_button_pressed

    return collision_ids, intersections
}

