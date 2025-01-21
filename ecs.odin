package main

REGISTRY_SIZE :: 1000

CompData :: struct {
    positions: [dynamic]Position,
    velocities: [dynamic]Velocity
}

ECSState :: struct {
    next_entity: uint,
    free_entities: [dynamic]uint,
    entities: SparseSet,
    comp_reg: [Component]SparseSet,
    comp_data: CompData
}

ecs_init :: proc(ecs: ^ECSState) {
    for c in Component {
        sst : SparseSet
        sst_init(&sst)
        ecs.comp_reg[c] = sst
    }
    sst_init(&ecs.entities)
    ecs.free_entities = make([dynamic]uint)
}

ecs_free :: proc(ecs: ^ECSState) {
    for c in Component {
        sst_delete(&ecs.comp_reg[c])
    }
    sst_delete(&ecs.entities)
    delete(ecs.free_entities)
}

query_system :: proc(ecs: ^ECSState, cmps: []Component, dt: f64, f: proc(^CompData, []uint, f64)) {
    entity_set := make([dynamic]uint); defer delete(entity_set)
    entities_with(ecs, cmps, &entity_set)
    f(&ecs.comp_data, entity_set[:], dt)
}

add_entity :: proc(ecs: ^ECSState) -> (id: uint) {
    if len(ecs.free_entities) > 0 {
        id = pop(&ecs.free_entities)
    } else {
        id = ecs.next_entity
        ecs.next_entity += 1
    }
    sst_add(&ecs.entities, id)
    return 
}

remove_entity :: proc(ecs: ^ECSState, entity: uint) -> bool {
    if _, ok := sst_remove(&ecs.entities, entity); ok {
        append(&ecs.free_entities, entity)
    }
    return false
}

entities_with :: proc(ecs: ^ECSState, cmps: []Component, out: ^[dynamic]uint) {
    e_loop: for e in ecs.entities.packed {
        for cmp in cmps {
            if !has_component(ecs, e, cmp) {
                continue e_loop
            }
        }
        append(out, e)
    }
}

has_component :: proc(ecs: ^ECSState, entity: uint, cmp: Component) -> bool {
    return sst_has(&ecs.comp_reg[cmp], entity)
}

add_component :: proc(ecs: ^ECSState, entity: uint, arr: ^[dynamic]$T, cmp: Component, val: T) {
    if sst_add(&ecs.comp_reg[cmp], entity) {
        append(arr, val)
    }
}

remove_component :: proc(ecs: ^ECSState, entity: uint, arr: ^[dynamic]$T, cmp: Component) {
    if idx, ok := sst_remove(&ecs.comp_reg[cmp], entity); ok {
        unordered_remove(arr, idx)
    }
}

