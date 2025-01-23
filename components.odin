package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "base:runtime"
import "core:fmt"

//=Components =============================================
Component :: struct { type: typeid }

ParentStruct :: struct {
    someprop: int
}

ChildStruct :: struct {
    using ps: ParentStruct,
    something_else: f32
}

Transform :: glm.mat4 
Shape :: enum{ Triangle, InvertedPyramid, Cube, None }
Velocity :: la.Vector3f32


COMPONENT_NAME :: enum {
    Velocity,
    Transform,
    Shape,
    None
}

CompData :: struct {
    velocity: [dynamic]Velocity,
    transform: [dynamic]Transform,
    shape: [dynamic]Shape
}

init_comp_data :: proc(cd: ^CompData) {
    cd.velocity = make([dynamic]Velocity)
    cd.transform = make([dynamic]Transform)
    cd.shape = make([dynamic]Shape)
}

free_comp_data :: proc(cd: ^CompData) {
    delete(cd.velocity)
    delete(cd.transform)
    delete(cd.shape)
}

//=Get=================================================
get_velocity :: proc(ecs: ^ECS, eid: uint) -> (^Velocity, bool) {
    if idx, ok := sst_get(&ecs.comp_reg[.Velocity], eid); ok {
        return &ecs.comp_data.velocity[idx], true 
    }
    return nil, false
}
get_transform :: proc(ecs: ^ECS, eid: uint) -> (^Transform, bool) {
    if idx, ok := sst_get(&ecs.comp_reg[.Transform], eid); ok {
        return &ecs.comp_data.transform[idx], true 
    }
    return nil, false
}
get_shape :: proc(ecs: ^ECS, eid: uint) -> (^Shape, bool) {
    if idx, ok := sst_get(&ecs.comp_reg[.Shape], eid); ok {
        return &ecs.comp_data.shape[idx], true 
    }
    return nil, false
}

//=Set=================================================
add_velocity :: proc(ecs: ^ECS, eid: uint, val: Velocity) {
    if sst_add(&ecs.comp_reg[.Velocity], eid) {
        append(&ecs.comp_data.velocity, val)
    }
}
add_transform :: proc(ecs: ^ECS, eid: uint, val: Transform) {
    if sst_add(&ecs.comp_reg[.Transform], eid) {
        append(&ecs.comp_data.transform, val)
    }
}
add_shape :: proc(ecs: ^ECS, eid: uint, val: Shape) {
    if sst_add(&ecs.comp_reg[.Shape], eid) {
        append(&ecs.comp_data.shape, val)
    }
}

//=Delete==============================================
remove_velocity :: proc(ecs: ^ECS, eid: uint) {
    if idx, ok := sst_remove(&ecs.comp_reg[.Velocity], eid); ok {
        unordered_remove(&ecs.comp_data.velocity, idx)
    }
}
remove_transform :: proc(ecs: ^ECS, eid: uint) {
    if idx, ok := sst_remove(&ecs.comp_reg[.Transform], eid); ok {
        unordered_remove(&ecs.comp_data.transform, idx)
    }
}
remove_shape :: proc(ecs: ^ECS, eid: uint) {
    if idx, ok := sst_remove(&ecs.comp_reg[.Shape], eid); ok {
        unordered_remove(&ecs.comp_data.shape, idx)
    }
}

