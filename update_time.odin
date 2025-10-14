package main

import "core:math"
// import "core:fmt"


updated_time_mult :: proc(time_mult: f32) -> f32 {
    // fmt.println(time_mult)
    return math.lerp(time_mult, f32(1.0), f32(0.05))
}

apply_bunny_hop_to_time_mult :: proc(time_mult: f32, did_bunny_hop: bool) -> f32 {
    if did_bunny_hop {
        return 1.75
    }
    return time_mult
}

apply_bounce_to_time_mult :: proc(time_mult: f32, collision_ids: map[int]struct{}, lgs: #soa[]Level_Geometry) -> f32 {
    for id in collision_ids {
        if .Bouncy in lgs[id].attributes {
            return 1.75
        }
    }
    return time_mult
}
