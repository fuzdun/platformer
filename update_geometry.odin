package main

import la "core:math/linalg"
import hm "core:container/handle_map"

update_geometry :: proc(
    lgs: ^Level_Geometry_State,
    pls: Player_State,
    triggers: Action_Triggers,
    collisions: Collision_Log,
    intersections: map[Handle]struct{},
    elapsed_time: f32,
    delta_time: f32
) {
    cts := pls.contact_state

    lg_it := hm.iterator_make(lgs)
    for lg, handle in hm.iterate(&lg_it) {
        if triggers.restart || triggers.checkpoint {
            lg.shatter_data.crack_time = 0
            lg.shatter_data.smash_time = 0
        }
        if handle in intersections {
            lg.transparency = clamp(lg.transparency - 5.0 * delta_time, 0.1, 1.0)
        } else {
            lg.transparency = clamp(lg.transparency + 5.0 * delta_time, 0.1, 1.0)
        }
    }

    if triggers.bunny_hop || triggers.small_hop {
        last_touched := cts.last_touched
        last_touched_lg := hm.get(lgs, last_touched)
        last_touched_lg.shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collisions {
        lg := hm.get(lgs, id) 
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

    // when MOVE {
    //     // test moving geometry
    //     // ---------------------------------------
    //     for _, lg_idx in new_lgs {
    //         move_geometry(new_lgs, phs, &new_position, collision_adjusted_cts, lg_idx)
    //     }
    // }

}

