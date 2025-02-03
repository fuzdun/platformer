package main

apply_velocities :: proc(lgs: Level_Geometry_State, dt: f64) {
    filter : bit_set[Level_Geometry_Component_Name] = { .Position, .Velocity }
    for &lg in lgs {
        lg.position = lg.position + (filter <= lg.attributes ? lg.velocity * f32(dt) : 0)
    }
    return
}

