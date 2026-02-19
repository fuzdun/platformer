package main

import la "core:math/linalg"
import hm "core:container/handle_map"
import "core:fmt"

update_geometry :: proc(
    lgs: ^Level_Geometry_State,
    lgrs: ^Level_Geometry_Render_Data_State,
    szs: ^Slide_Zone_State,
    pls: Player_State,
    triggers: Action_Triggers,
    collisions: Collision_Log,
    elapsed_time: f32,
    delta_time: f32
) {
    cts := pls.contact_state


    // #####################################################
    // STANDARD LEVEL GEOMETRY
    // #####################################################

    for lg, idx in lgs {
        render_data := hm.get(lgrs, lg.render_data_handle)    
        render_data.transform = lg.transform
    }

    if triggers.restart || triggers.checkpoint {
        for &lg in lgs {
            // lg.shatter_data.crack_time = 0
            // lg.shatter_data.smash_time = 0

            rd := hm.get(lgrs, lg.render_data_handle)
            rd.shatter_data.crack_time = 0
            rd.shatter_data.smash_time = 0
        }
    }

    if triggers.bunny_hop {
        last_touched := cts.last_touched
        // lgs[last_touched].shatter_data.crack_time = elapsed_time - BREAK_DELAY

        rd := hm.get(lgrs, lgs[last_touched].render_data_handle)
        rd.shatter_data.crack_time = elapsed_time - BREAK_DELAY
    }

    for id in collisions {
        lg := &lgs[id]
        // if .Dash_Breakable in lg.attributes && pls.mode == .Dashing {
        //     lg.shatter_data.smash_time = lg.shatter_data.smash_time == 0.0 ? elapsed_time : lg.shatter_data.smash_time 
        //     lg.shatter_data.smash_dir = la.normalize(pls.velocity)
        //     lg.shatter_data.smash_pos = pls.position
        // } else if .Slide_Zone in lg.attributes && pls.mode == .Sliding {
        //     // do nothing
        // } else if .Breakable in lg.attributes {
        //     lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.shatter_data.crack_time
        // } else if .Crackable in lg.attributes {
        //     lg.shatter_data.crack_time = lg.shatter_data.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.shatter_data.crack_time
        // }

        rd := hm.get(lgrs, lg.render_data_handle)
        if .Dash_Breakable in lg.attributes && pls.mode == .Dashing {
            rd.shatter_data.smash_time = rd.shatter_data.smash_time == 0.0 ? elapsed_time : rd.shatter_data.smash_time 
            rd.shatter_data.smash_dir = la.normalize(pls.velocity)
            rd.shatter_data.smash_pos = pls.position
        } else if .Slide_Zone in lg.attributes && pls.mode == .Sliding {
            // do nothing
        } else if .Breakable in lg.attributes {
            rd.shatter_data.crack_time = rd.shatter_data.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : rd.shatter_data.crack_time
        } else if .Crackable in lg.attributes {
            rd.shatter_data.crack_time = rd.shatter_data.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : rd.shatter_data.crack_time
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
        // lgs[sz.id].transparency = sz.transparency_t

        rd := hm.get(lgrs, lgs[sz.id].render_data_handle)
        rd.transparency = sz.transparency_t
    }

    clear(&szs.intersected)
    for sz in szs.entities {
        // if lgs[sz.id].shatter_data.crack_time != 0 {
        if hm.get(lgrs, lgs[sz.id].render_data_handle).shatter_data.crack_time != 0 {
            continue
        }
        if hit, _ := sphere_obb_intersection(sz, pls.position, PLAYER_SPHERE_RADIUS); hit {
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
}

