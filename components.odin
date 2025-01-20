package main
import la "core:math/linalg"

Component :: enum { Position, Velocity }

Position :: la.Vector3f64
positions: [dynamic]Position
add_position ::    proc(entity: uint, val: Position) { add_component(   entity, &positions, .Position, val) }
remove_position :: proc(entity: uint)                { remove_component(entity, &positions, .Position) }

Velocity :: la.Vector3f64
velocities: [dynamic]Velocity
add_velocity ::    proc(entity: uint, val: Velocity) { add_component(   entity, &velocities, .Velocity, val) }
remove_velocity :: proc(entity: uint)                { remove_component(entity, &velocities, .Velocity) }
