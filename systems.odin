package main

apply_velocities :: proc(lgs: Level_Geometry_State, dt: f32) {
    filter : bit_set[Level_Geometry_Component_Name] = { .Position, .Velocity }
    for &lg in lgs {
        lg.position = lg.position + (filter <= lg.attributes ? lg.velocity * dt : 0)
    }
    return
}

