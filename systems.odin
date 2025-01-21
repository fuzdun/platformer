package main
import "core:fmt"

apply_velocities :: proc(ecs: ^ECSState, dt: f64) {
    using ecs.comp_data
    ents := entities_with(ecs, {.Position, .Velocity})
    for e in ents {
        positions[e] += velocities[e] * dt
    }
}
