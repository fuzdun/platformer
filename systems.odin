package main

apply_velocities :: proc(ecs: ^ECSState, dt: f64) {
    query_system(ecs, {.Position, .Velocity}, dt, proc(cd: ^CompData, ents: []uint, dt: f64) {
        for e in ents {
            cd.positions[e] += cd.velocities[e] * dt
        }
    })
}
