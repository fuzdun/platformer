package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"
import hm "core:container/handle_map"

INFINITE_HOP :: true

GROUND_BASE: f32 : -14.00

first_frame := true

set_state :: proc(pls: ^Player_State, next: Mode_State) {
    fmt.println("to:", next)
    switch &s in next {
    case On_Surface:
        pls.state = s
    case Airborne:
        pls.state = s
    case Jumping:
        pls.state = s
    }
}

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

    is_hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN

    x := [3]f32{1, 0, 0}
    y := [3]f32{0, 1, 0}

    next_z_position: = 10 - BEAT_SPACE * current_beat_progress
    pls.velocity.z = (next_z_position - pls.position.z) / delta_time

    switch &state in pls.state {
    case On_Surface:
        normalized_contact_ray := la.normalize(state.contact_ray)
        pls.velocity.xy *= math.pow(FRICTION, delta_time)

        if state.surface_type == .GROUND {
            surface_x := la.normalize0(x + la.dot(x, state.contact_ray) * state.contact_ray)
            pls.velocity += surface_x * triggers.move.x * GROUND_ACCEL * delta_time
            // fmt.println("before:", pls.velocity.x)
        }
        if state.surface_type == .SLOPE {
            surface_x := la.normalize0(x + la.dot(x, state.contact_ray) * state.contact_ray)
            pls.velocity += surface_x * triggers.move.x * SLOPE_ACCEL * delta_time
            pls.velocity.y -= SLOPE_GRAV * delta_time
        }
        if state.surface_type == .WALL {
            surface_y := la.normalize0(y + la.dot(y, state.contact_ray) * state.contact_ray)
            pls.velocity += surface_y * triggers.move.y * WALL_ACCEL * delta_time
            pls.velocity.y -= WALL_GRAV * delta_time
        }
        pls.velocity -= la.dot(pls.velocity, normalized_contact_ray) * normalized_contact_ray
        pls.velocity.xy = la.clamp_length(pls.velocity.xy, MAX_PLAYER_SPEED)
        // fmt.println("after:", pls.velocity.x)

        if triggers.jump {
            jump_start := current_beat_progress
            jump_end: f32
            if triggers.small_hop || triggers.bunny_hop {
                jump_end = math.round(bpm_jump_start) + TEST_JUMP_BEAT_COUNT
            } else {
                raw_jump_end := current_beat_progress + TEST_JUMP_BEAT_COUNT
                jump_end = math.lerp(raw_jump_end, math.round(raw_jump_end), f32(0.75))
            }
            set_state(pls, Jumping {
                jump_start = jump_start,
                jump_end = jump_end
            })
        }

    case Jumping:
        pls.velocity += triggers.move.x * AIR_ACCEL * delta_time
        pls.velocity.x = math.clamp(pls.velocity.x, -MAX_PLAYER_SPEED, MAX_PLAYER_SPEED)
        jump_midpoint := state.jump_end - ((state.jump_end - state.jump_start) * 0.5)
        arc_len := jump_midpoint - state.jump_start
        jump_progress := math.max(current_beat_progress - state.jump_start, 0)
        jump_grav := -(2.0 * TEST_JUMP_HEIGHT) / (arc_len * arc_len)
        jump_init_vel := -jump_grav * arc_len
        next_y_position := GROUND_BASE + jump_init_vel * jump_progress + 0.5 * jump_grav * jump_progress * jump_progress
        pls.velocity.y = (next_y_position - pls.position.y) / delta_time

    case Airborne:
        pls.velocity += x * triggers.move.x * AIR_ACCEL * delta_time
        pls.velocity.y -= GRAV * delta_time
    }

    new_mode := pls.mode
    new_jump_enabled := triggers.new_jump_enabled


    // #####################################################
    // APPLY VELOCITY, HANDLE COLLISIONS
    // #####################################################

    collision_ids, contact_ids, touched_ground := apply_velocity(
        pls,
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
            new_normalized_contact_ray := la.normalize0(pls.contact_state.contact_ray)
            bounced_velocity_dir := la.normalize0(pls.velocity) - new_normalized_contact_ray
            pls.velocity = bounced_velocity_dir * BOUNCE_VELOCITY
            pls.contact_state.state = .IN_AIR
            break
        }
    }

    // if touched_ground {
    //     new_dash_enabled = true
    // }

    // collided_cts := collision_adjusted_cts.state

    // handle checkpoint / restart
    // -------------------------------------------
    if triggers.restart  {
        pls.velocity = [3]f32{0, 0, 0}
        pls.position = INIT_PLAYER_POS
        pls.state = Airborne {

        }
    }

    if triggers.checkpoint {
        pls.velocity = [3]f32{0, 0, 0}
        pls.position = [3]f32{pls.position.x, 25, pls.position.z}
        jump_start := current_beat_progress
        jump_end: f32
        if triggers.small_hop || triggers.bunny_hop {
            jump_end = math.round(bpm_jump_start) + TEST_JUMP_BEAT_COUNT
        } else {
            raw_jump_end := current_beat_progress + TEST_JUMP_BEAT_COUNT
            jump_end = math.lerp(raw_jump_end, math.round(raw_jump_end), f32(0.75))
        }
        set_state(pls, Airborne{})
    }

    // handle round end
    // -------------------------------------------
    if gs.time_remaining == 0 {
        pls.position = [3]f32{5000, 5000, 5000}
        pls.velocity = 0
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
        pls.position.y = GROUND_BASE + jump_init_vel * jump_progress + 0.5 * jump_grav * jump_progress * jump_progress
        pls.velocity.yz = pls.position.yz - pls.position.yz
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
    pls.hurt_t             = new_hurt_t
    pls.broke_t            = new_broke_t
    pls.jump_enabled       = new_jump_enabled

    // move to input update
    pls.jump_pressed_time  = triggers.jump_pressed_time

    // move to input update
    pls.jump_held          = triggers.jump_button_pressed

    return collision_ids, intersections
}

