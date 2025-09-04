package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"


apply_restart_to_lgs :: proc(is: Input_State, lgs: Level_Geometry_Soa) -> Level_Geometry_Soa {
    defer delete(lgs)
    new_lgs := dynamic_soa_copy(lgs)
    if is.r_pressed {
        for &lg in new_lgs {
            lg.crack_time = 0
            lg.break_time = 0
        }
    }
    return new_lgs
}

apply_bunny_hop_to_lgs :: proc(lgs: Level_Geometry_Soa, did_bunny_hop: bool, last_touched: int, elapsed_time: f32) -> Level_Geometry_Soa {
    defer delete(lgs)
    new_lgs := dynamic_soa_copy(lgs)
    if did_bunny_hop {
        new_lgs[last_touched].crack_time = elapsed_time - BREAK_DELAY
        // for id in contact_ids {
        //     new_lgs[id].crack_time = elapsed_time - BREAK_DELAY
        // }
    }
    return new_lgs 
}

apply_collisions_to_lgs :: proc(lgs: Level_Geometry_Soa, dashing: bool, sliding: bool, position: [3]f32, velocity: [3]f32, collision_ids: map[int]struct{}, elapsed_time: f32) -> Level_Geometry_Soa {
    defer delete(lgs)
    new_lgs := dynamic_soa_copy(lgs)
    for id in collision_ids {
        lg := &new_lgs[id]
        if .Dash_Breakable in lg.attributes && dashing {
            lg.break_time = lg.break_time == 0.0 ? elapsed_time : lg.break_time
            lg.break_dir = la.normalize(velocity)
            lg.break_pos = position
        } else if .Slide_Zone in lg.attributes && sliding {
            // do nothing
        } else if .Breakable in lg.attributes {
            lg.crack_time = lg.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : lg.crack_time
        } else if .Crackable in lg.attributes {
            lg.crack_time = lg.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : lg.crack_time
        }
    }
    return new_lgs 
}

apply_transparency_to_lgs :: proc(lgs: Level_Geometry_Soa, szs: #soa[]Obb, elapsed_time: f32) -> Level_Geometry_Soa {
    defer delete(lgs)
    new_lgs := dynamic_soa_copy(lgs)
    for &sz in szs {
        new_lgs[sz.id].transparency = sz.transparency_t
    }
    return new_lgs
}


apply_transparency_to_szs :: proc(szs: #soa[dynamic]Obb, intersections: map[int]struct{}, delta_time: f32) -> #soa[dynamic]Obb {
    defer delete(szs)
    new_szs := dynamic_soa_copy(szs)

    for &sz in new_szs {
        if sz.id in intersections {
            sz.transparency_t = clamp(sz.transparency_t - 5.0 * delta_time, 0.1, 0.5)
        } else {
            sz.transparency_t = clamp(sz.transparency_t + 5.0 * delta_time, 0.1, 0.5)
        }
    }
    return new_szs
}

