package main

SparseSet :: struct{
    sparse: [REGISTRY_SIZE]uint,
    packed: [dynamic]uint
}

sst_init :: proc(sst: ^SparseSet) {
    sst.packed = make([dynamic]uint)
}

sst_delete :: proc(sst: ^SparseSet) {
    delete(sst.packed)
}

sst_add :: proc(sst: ^SparseSet, entity: uint) -> (bool) {
    if !sst_has(sst, entity) {
        pos := uint(len(sst.packed))
        append(&sst.packed, entity)
        sst.sparse[entity] = pos
        return true
    }
    return false
}

sst_remove :: proc(sst: ^SparseSet, entity: uint) -> (uint, bool) {
    if sst_has(sst, entity) {
        packed_i := sst.sparse[entity]
        sst.sparse[sst.packed[len(sst.packed) - 1]] = packed_i
        unordered_remove(&sst.packed, packed_i)
        return packed_i, true
    }
    return 0, false
}

sst_get :: proc(sst: ^SparseSet, entity: uint) -> (uint, bool) {
    if sst_has(sst, entity) {
        return sst.sparse[entity], true
    }
    return 0, false
}

sst_has :: proc(sst: ^SparseSet, entity: uint) -> bool {
    return len(sst.packed) > 0 && sst.packed[sst.sparse[entity]] == entity
}
