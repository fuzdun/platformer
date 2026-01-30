package main

import "constants"
import la "core:math/linalg"

update_geometry :: proc(
    lgs: ^Level_Geometry_State,
    szs: ^Slide_Zone_State,
    pls: Player_State,
    triggers: Action_Triggers,
    collisions: Collision_Log,
    elapsed_time: f32,
    delta_time: f32
) {
    using constants
    cts := pls.contact_state

    new_lgs := dynamic_soa_copy(lgs^)
    new_szs_entities := dynamic_soa_copy(szs.entities)
    new_szs_intersections := make(map[int]struct{})

    // #####################################################
    // STANDARD LEVEL GEOMETRY
    // #####################################################

    if triggers.restart || triggers.checkpoint {
        for &lg in new_lgs {
            lg.shatter_data.crack_time = 0
            lg.shatter_data.smash_time = 0
        }
    }

    if triggers.bunny_hop {
       last_touched := cts.last_touched
       new_lgs[last_touched].shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collisions {
        lg := &new_lgs[id]
        if .Dash_Breakable in lg.attributes && pls.mode == .Dashing {
            lg.shatter_data.smash_time = lg.shatter_data.smash_time == 0.0 ? elapsed_time : lg.shatter_data.smash_time 
            lg.shatter_data.smash_dir = la.normalize(pls.velocity)
            lg.shatter_data.smash_pos = pls.position
        } else if .Slide_Zone in lg.attributes && pls.mode == .Sliding {
            // do nothing
        } else if .Breakable in lg.attributes {
            lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.shatter_data.crack_time
        } else if .Crackable in lg.attributes {
            lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.shatter_data.crack_time
        }
    }

    when MOVE {
        // test moving geometry
        // ---------------------------------------
        for _, lg_idx in new_lgs {
            move_geometry(new_lgs, phs, &new_position, collision_adjusted_cts, lg_idx)
        }
    }


    // #####################################################
    // SLIDE ZONES
    // #####################################################

    for &sz in szs.entities {
        new_lgs[sz.id].transparency = sz.transparency_t
    }

    for sz in szs.entities {
        if new_lgs[sz.id].shatter_data.crack_time != 0 {
            continue
        }
        if hit, _ := sphere_obb_intersection(sz, pls.position, PLAYER_SPHERE_RADIUS); hit {
            new_szs_intersections[sz.id] = {}
        }
    }

    for &sz in new_szs_entities {
        if sz.id in new_szs_intersections {
            sz.transparency_t = clamp(sz.transparency_t - 5.0 * delta_time, 0.1, 1.0)
        } else {
            sz.transparency_t = clamp(sz.transparency_t + 5.0 * delta_time, 0.1, 1.0)
        }
    }

    dynamic_soa_swap(lgs, new_lgs)
    dynamic_soa_swap(&szs.entities, new_szs_entities)
    set_swap(&szs.intersected, new_szs_intersections)
}

