package main

apply_velocities :: proc() {
    query_system({.Position, .Velocity}, proc(ents: []uint) {
        for e in ents {
            positions[e] += velocities[e]
        }
    })
}
