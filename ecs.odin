package main
import "core:fmt"
import "base:runtime"

REGISTRY_SIZE :: 1000

// Entities
next_entity : uint = 0
free_entities : [dynamic]uint
entities : SparseSet

component_registry : [Component]SparseSet

ecs_init :: proc() {
    for c in Component {
        sst : SparseSet
        sst_init(&sst)
        component_registry[c] = sst
    }
    sst_init(&entities)
    free_entities = make([dynamic]uint)
}

ecs_free :: proc() {
    for c in Component {
        sst_delete(&component_registry[c])
    }
    sst_delete(&entities)
    delete(free_entities)
}

query_system :: proc(cmps: []Component, f: proc([]uint)) {
    entity_set := make([dynamic]uint); defer delete(entity_set)
    entities_with(cmps, &entity_set)
    f(entity_set[:])
}

add_entity :: proc() -> (id: uint) {
    if len(free_entities) > 0 {
        id = pop(&free_entities)
    } else {
        id = next_entity
        next_entity += 1
    }
    sst_add(&entities, id)
    return 
}

remove_entity :: proc(entity: uint) -> bool {
    if _, ok := sst_remove(&entities, entity); ok {
        append(&free_entities, entity)
    }
    return false
}

entities_with :: proc(cmps: []Component, out: ^[dynamic]uint) {
    e_loop: for e in entities.packed {
        for cmp in cmps {
            if !has_component(e, cmp) {
                continue e_loop
            }
        }
        append(out, e)
    }
}

has_component :: proc(entity: uint, cmp: Component) -> bool {
    return sst_has(&component_registry[cmp], entity)
}

add_component :: proc(entity: uint, arr: ^[dynamic]$T, cmp: Component, val: T) {
    if sst_add(&component_registry[cmp], entity) {
        append(arr, val)
    }
}

remove_component :: proc(entity: uint, arr: ^[dynamic]$T, cmp: Component) {
    if idx, ok := sst_remove(&component_registry[cmp], entity); ok {
        unordered_remove(arr, idx)
    }
}

