package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "base:runtime"
import "core:fmt"

//=Components =============================================
Component :: struct { type: typeid }

Transform :: glm.mat4 
Shape :: enum{ Triangle, InvertedPyramid, Cube, Sphere, Plane, None }
Velocity :: la.Vector3f32
ActiveShaders :: bit_set[ProgramName]


COMPONENT_NAME :: enum {
    Velocity,
    Transform,
    Shape,
    ActiveShaders,
    None
}

CompData :: struct {
    velocity: [dynamic]Velocity,
    transform: [dynamic]Transform,
    shape: [dynamic]Shape,
    active_shaders: [dynamic]ActiveShaders 
}

init_comp_data :: proc(cd: ^CompData) {
    cd.velocity = make([dynamic]Velocity)
    cd.transform = make([dynamic]Transform)
    cd.shape = make([dynamic]Shape)
    cd.active_shaders = make([dynamic]ActiveShaders)
}

free_comp_data :: proc(cd: ^CompData) {
    delete(cd.velocity)
    delete(cd.transform)
    delete(cd.shape)
    delete(cd.active_shaders)
}

//=Get=================================================
get_shaders :: proc(ecs: ^ECS, eid: uint) -> (^ActiveShaders, bool) {
    if idx, ok := sst_get(&ecs.comp_reg[.ActiveShaders], eid); ok {
        return &ecs.comp_data.active_shaders[idx], true 
    }
    return nil, false
}
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
add_shaders :: proc(ecs: ^ECS, eid: uint, val: ActiveShaders) {
    if sst_add(&ecs.comp_reg[.ActiveShaders], eid) {
        append(&ecs.comp_data.active_shaders, val)
    }
}
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
remove_shaders :: proc(ecs: ^ECS, eid: uint) {
    if idx, ok := sst_remove(&ecs.comp_reg[.ActiveShaders], eid); ok {
        unordered_remove(&ecs.comp_data.active_shaders, idx)
    }
}
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

