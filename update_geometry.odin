package main

import  "core:fmt"
import la "core:math/linalg"


apply_restart_to_lgs :: proc(is: Input_State, lgs: Level_Geometry_Soa) -> Level_Geometry_Soa {
    lgs := dynamic_soa_copy(lgs)
    if is.r_pressed {
        for &lg in lgs {
            lg.crack_time = 0
            lg.break_time = 0
        }
    }
    return lgs
}


apply_collisions_to_lgs :: proc(lgs: Level_Geometry_Soa, pls: Player_State, collision_ids: map[int]struct{}, elapsed_time: f32) -> Level_Geometry_Soa {
    defer delete(lgs)
    lgs := dynamic_soa_copy(lgs)
    for id in collision_ids {
        lg := &lgs[id]
        if .Dash_Breakable in lg.attributes && pls.dash_state.dashing {
            lg.break_time = lg.break_time == 0.0 ? elapsed_time : lg.break_time
            lg.break_dir = la.normalize(pls.velocity)
            lg.break_pos = pls.position
            // lg.crack_time = lg.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.crack_time
        } else if .Hazardous in lg.attributes {
            lg.crack_time = lg.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.crack_time
        } else if .Crackable in lg.attributes {
            lg.crack_time = lg.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.crack_time
        }
    }
    return lgs 
}


apply_bunny_hop_to_lgs :: proc(lgs: Level_Geometry_Soa, pls: Player_State,  elapsed_time: f32) -> Level_Geometry_Soa {
    defer delete(lgs)
    lgs := dynamic_soa_copy(lgs)
    if did_bunny_hop(pls, elapsed_time) {
        lgs[pls.contact_state.last_touched].crack_time = elapsed_time - BREAK_DELAY
    }
    return lgs 
}

