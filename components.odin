package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

Component :: enum {
    Position,
    Velocity,
    Transform,
    Shape
}

CompData :: struct {
    positions: [dynamic]Position,
    velocities: [dynamic]Velocity,
    transforms: [dynamic]Transform,
    shapes: [dynamic]Shape
}


Position :: la.Vector3f64
add_position :: proc(ecs: ^ECSState, entity: uint, val: Position) {
    add_component(ecs, entity, &ecs.comp_data.positions, .Position, val)
}
remove_position :: proc(ecs: ^ECSState, entity: uint) {
    remove_component(ecs, entity, &ecs.comp_data.positions, .Position)
}

Velocity :: la.Vector3f32
add_velocity :: proc(ecs: ^ECSState, entity: uint, val: Velocity) {
    add_component(ecs, entity, &ecs.comp_data.velocities, .Velocity, val)
}
remove_velocity :: proc(ecs: ^ECSState, entity: uint) {
    remove_component(ecs, entity, &ecs.comp_data.velocities, .Velocity)
}

Transform ::glm.mat4 
add_transform :: proc(ecs: ^ECSState, entity: uint, val: Transform) {
    add_component(ecs, entity, &ecs.comp_data.transforms, .Transform, val)
}
remove_transform :: proc(ecs: ^ECSState, entity: uint) {
    remove_component(ecs, entity, &ecs.comp_data.transforms, .Transform)
}


Shape :: enum{ Triangle, InvertedPyramid, Cube, None }
add_shape :: proc(ecs: ^ECSState, entity: uint, val: Shape) {
    add_component(ecs, entity, &ecs.comp_data.shapes, .Shape, val)
}
remove_shape :: proc(ecs: ^ECSState, entity: uint) {
    remove_component(ecs, entity, &ecs.comp_data.shapes, .Shape)
}

