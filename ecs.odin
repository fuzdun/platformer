package main
import "core:fmt"

REGISTRY_SIZE :: 2000

Entity :: map[Component]uint

ECS :: struct {
    next_entity: uint,
    free_entities: [dynamic]uint,
    entities: SparseSet,
    comp_reg: [Component]SparseSet,
    //comp_data: CompData
    comp_data: map[typeid]CompDetails
}

ecs_init :: proc(ecs: ^ECS) {
    for c in Component {
        sst : SparseSet
        sst_init(&sst)
        ecs.comp_reg[c] = sst
    }
    sst_init(&ecs.entities)
    ecs.free_entities = make([dynamic]uint)
}

ecs_free :: proc(ecs: ^ECS) {
    for c in Component {
        sst_delete(&ecs.comp_reg[c])
    }
    sst_delete(&ecs.entities)
    delete(ecs.free_entities)
}

add_entity :: proc(ecs: ^ECS) -> (id: uint) {
    if len(ecs.free_entities) > 0 {
        id = pop(&ecs.free_entities)
    } else {
        id = ecs.next_entity
        ecs.next_entity += 1
    }
    sst_add(&ecs.entities, id)
    return 
}

remove_entity :: proc(ecs: ^ECS, entity: uint) -> bool {
    if _, ok := sst_remove(&ecs.entities, entity); ok {
        append(&ecs.free_entities, entity)
    }
    return false
}

has_component :: proc(ecs: ^ECS, entity: uint, cmp: Component) -> bool {
    return sst_has(&ecs.comp_reg[cmp], entity)
}

get_component_idx :: proc(ecs: ^ECS, entity: uint, cmp: Component) -> (uint, bool) {
    return sst_get(&ecs.comp_reg[cmp], entity)
}

add_component :: proc(ecs: ^ECS, entity: uint, arr: ^[dynamic]$T, cmp: Component, val: T) {
    if sst_add(&ecs.comp_reg[cmp], entity) {
        append(arr, val)
    }
}

remove_component :: proc(ecs: ^ECS, entity: uint, arr: ^[dynamic]$T, cmp: Component) {
    if idx, ok := sst_remove(&ecs.comp_reg[cmp], entity); ok {
        unordered_remove(arr, idx)
    }
}

