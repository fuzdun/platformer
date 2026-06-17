package main

import hm "core:container/handle_map"

update_geometry :: proc(
    entities: ^Level_Geometry_State,
    pls: Player_State,
    triggers: Action_Triggers,
    collisions: Collision_Log,
    elapsed_time: f32,
    delta_time: f32
) {
    intersections := make(map[Handle]struct{})
    lg_it := hm.iterator_make(entities)
    for lg, handle in hm.iterate(&lg_it) {
        #partial switch v in lg.variant {
        case Shatter_Block:
            if v.shatter_data.crack_time != 0 {
                continue
            }
        }
        sz_obb := lg_to_obb(lg^)
        if hit, _ := sphere_obb_intersection(sz_obb, pls.position, PLAYER_SPHERE_RADIUS); hit {
            intersections[handle] = {}
        }
    }

    lg_it = hm.iterator_make(entities)
    for lg, handle in hm.iterate(&lg_it) {
        #partial switch &v in lg.variant {
        case Shatter_Block:
            if triggers.restart || triggers.checkpoint {
                v.shatter_data.crack_time = 0
                v.shatter_data.smash_time = 0
            }
        case Slide_Zone:
            if handle in intersections {
                v.transparency = clamp(v.transparency - 5.0 * delta_time, 0.1, 1.0)
            } else {
                v.transparency = clamp(v.transparency + 5.0 * delta_time, 0.1, 1.0)
            }
        }
    }

    if triggers.bunny_hop || triggers.small_hop {
        last_touched := pls.last_touched
        last_touched_lg := hm.get(entities, last_touched)
        #partial switch &v in last_touched_lg.variant {
        case Shatter_Block:
            v.shatter_data.crack_time = elapsed_time - BREAK_DELAY
        }
    }

    for id in collisions {
        lg := hm.get(entities, id) 
        #partial switch &v in lg.variant {
        case Shatter_Block:
            if .Breakable in lg.attributes {
                v.shatter_data.crack_time = v.shatter_data.crack_time == 0.0 ? elapsed_time - BREAK_DELAY : v.shatter_data.crack_time
            } else if .Crackable in lg.attributes {
                v.shatter_data.crack_time = v.shatter_data.crack_time == 0.0 ? elapsed_time + CRACK_DELAY : v.shatter_data.crack_time
            }
        }
        // if .Dash_Breakable in lg.attributes && pls.mode == .Dashing {
        //     lg.shatter_data.smash_time = lg.shatter_data.smash_time == 0.0 ? elapsed_time : lg.shatter_data.smash_time 
        //     lg.shatter_data.smash_dir = la.normalize(pls.velocity)
        //     lg.shatter_data.smash_pos = pls.position
        // } else if .Slide_Zone in lg.attributes && pls.mode == .Sliding {
        //     // do nothing
    }
}

