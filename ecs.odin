package main
import "core:fmt"
import "base:runtime"

ECS :: struct {
    next_entity: uint,
    free_entities: [dynamic]uint,
    entities: SparseSet,
    comp_reg: map[COMPONENT_NAME]SparseSet,
    comp_data: CompData,
}

//Procs=========================================
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

has_component :: proc(ecs: ^ECS, entity: uint, cmp: COMPONENT_NAME) -> bool {
    return sst_has(&ecs.comp_reg[cmp], entity)
}


//Memory=========================================
ecs_init :: proc(ecs: ^ECS) {
    ecs.comp_reg = make(map[COMPONENT_NAME]SparseSet)
    for c in COMPONENT_NAME {
        sst : SparseSet
        sst_init(&sst)
        ecs.comp_reg[c] = sst
    }
    sst_init(&ecs.entities)
    ecs.free_entities = make([dynamic]uint)
    init_comp_data(&ecs.comp_data)
}

ecs_free :: proc(ecs: ^ECS) {
    for c in COMPONENT_NAME {
        sst_delete(&ecs.comp_reg[c])
    }
    sst_delete(&ecs.entities)
    delete(ecs.free_entities)
    delete(ecs.comp_reg)
}

//Queries=========================================
entities_with :: proc(ecs: ^ECS, cmps: []COMPONENT_NAME) -> (out: [dynamic]uint) {
    out = make([dynamic]uint)
    shortest_len := REGISTRY_SIZE + 1
    shortest_cmp_i := 0 
    for cmp, cmp_i in cmps {
        reg := ecs.comp_reg[cmp]
        if l := len(reg.packed); l < shortest_len {
            shortest_len = l
            shortest_cmp_i = cmp_i 
        }
    }
    to_check := arr_with_removed(cmps, shortest_cmp_i)
    defer delete(to_check)
    e_loop: for e in ecs.comp_reg[cmps[shortest_cmp_i]].packed {
        for cmp in to_check {
            if !has_component(ecs, e, cmp) do continue e_loop
        }
        append(&out, e)
    }
    return
}

arr_with_removed :: proc(arr: []$T, idx: int) -> (out: []T) {
    l := len(arr)   
    out = make([]T, l - 1)
    count := 0
    for i in 0..<l {
        if i != idx {
            out[count] = arr[i]
            count += 1
        }
    }
    return 
}

