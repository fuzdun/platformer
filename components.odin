package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "base:runtime"

Component :: enum {
    Velocity,
    Transform,
    Shape,
}

CompDetails :: struct {
    type: typeid,
    data: ^runtime.Raw_Dynamic_Array,
    reg: SparseSet,
}


//CompData :: [Component]CompDetails {
    //velocities: [dynamic]Velocity,
    //transforms: [dynamic]Transform,
    //shapes: [dynamic]Shape,
//}

//get_comp_array :: proc() -> ^[dynamic]T{
//
//}


//Velocity :: la.Vector3f32
//add_velocity :: proc(ecs: ^ECS, eid: uint, val: Velocity) {
//    add_component(ecs, eid, &ecs.comp_data.velocities, .Velocity, val)
//}
//remove_velocity :: proc(ecs: ^ECS, eid: uint) {
//    remove_component(ecs, eid, &ecs.comp_data.velocities, .Velocity)
//}
//get_velocity_entity :: proc(ecs: ^ECS, e: Entity) -> ^Velocity {
//    return &ecs.comp_data.velocities[e[.Velocity]]
//}
//get_velocity_eid :: proc(ecs: ^ECS, eid: uint) -> ^Velocity {
//    return &ecs.comp_data.velocities[eid]
//}
//get_velocity :: proc {get_velocity_eid, get_velocity_entity}
//
//
//Transform ::glm.mat4 
//add_transform :: proc(ecs: ^ECS, eid: uint, val: Transform) {
//    add_component(ecs, eid, &ecs.comp_data.transforms, .Transform, val)
//}
//remove_transform :: proc(ecs: ^ECS, eid: uint) {
//    remove_component(ecs, eid, &ecs.comp_data.transforms, .Transform)
//}
//get_transform_entity :: proc(ecs: ^ECS, e: Entity) -> ^Transform {
//    return &ecs.comp_data.transforms[e[.Transform]]
//}
//get_transform_eid :: proc(ecs: ^ECS, eid: uint) -> ^Transform {
//    return &ecs.comp_data.transforms[get_component_idx(ecs, eid, .Transform)]
//}
//
//
//Shape :: enum{ Triangle, InvertedPyramid, Cube, None }
//add_shape :: proc(ecs: ^ECS, eid: uint, val: Shape) {
//    add_component(ecs, eid, &ecs.comp_data.shapes, .Shape, val)
//}
//remove_shape :: proc(ecs: ^ECS, eid: uint) {
//    remove_component(ecs, eid, &ecs.comp_data.shapes, .Shape)
//}
//get_shape_entity :: proc(ecs: ^ECS, e: Entity) -> ^Shape {
//    return &ecs.comp_data.shapes[e[.Shape]]
//}
//get_shape_eid :: proc(ecs: ^ECS, eid: uint) -> ^Shape {
//    return &ecs.comp_data.shapes[eid]
//}
//
