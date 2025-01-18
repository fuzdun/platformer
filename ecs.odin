package main

ComponentArray :: struct($T: typeid, $N: int){
    registry: struct {
        sparse: [N]int,
        packed: [dynamic]int
    },
    data: [dynamic]T
}

ca_init :: proc(ca: ^ComponentArray($T, $N)) {
    ca.registry.packed = make([dynamic]int)
    ca.data = make([dynamic]T)
}

ca_delete :: proc(ca: ^ComponentArray($T, $N)) {
    delete(ca.registry.packed)
    delete(ca.data)
}

ca_add :: proc(ca: ^ComponentArray($T, $N), entity: int, val: T) {
    if !ca_has(ca, entity) {
        pos := len(ca.registry.packed)
        append(&ca.registry.packed, entity)
        ca.registry.sparse[entity] = pos
        append(&ca.data, val)
    }
}

ca_get :: proc(ca: ^ComponentArray($T, $N), entity: int) -> (val: T, ok: bool) {
    if ca_has(ca, entity) {
        return ca.data[ca.registry.sparse[entity]], true
    } else {
        ok = false
    }
    return
}

ca_remove :: proc(ca: ^ComponentArray($T, $N), entity: int) {
    if ca_has(ca, entity) {
        reg := &ca.registry
        packed_i := reg.sparse[entity]
        reg.sparse[reg.packed[len(reg.packed) - 1]] = packed_i
        unordered_remove(&reg.packed, packed_i)
        unordered_remove(&ca.data, packed_i)
    }
}

ca_has :: proc(ca: ^ComponentArray($T, $N), entity: int) -> bool {
    return len(ca.data) > 0 && ca.registry.packed[ca.registry.sparse[entity]] == entity
}

test :: proc() {
    ca : ComponentArray(string, 20)
    ca_init(&ca)
    ca_delete(&ca)
}