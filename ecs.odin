package main
import "core:fmt"
import "base:runtime"
import la "core:math/linalg"


Position :: distinct la.Vector3f64

ComponentMap :: struct{
    Position: [dynamic]Position
}

ComponentRegistry :: map[typeid]SparseSet(100)

SparseSet :: struct($N: int){
    sparse: [N]int,
    packed: [dynamic]int
}

register_component :: proc($C: typeid) {

}

sst_init :: proc(sst: ^SparseSet($N)) {
    sst.packed = make([dynamic]int)
}

sst_delete :: proc(sst: ^SparseSet($N)) {
    delete(sst.packed)
}

sst_add :: proc(sst: ^SparseSet($N), entity: int) -> (int, bool) {
    if !sst_has(sst, entity) {
        pos := len(sst.packed)
        append(&sst.packed, entity)
        sst.sparse[entity] = pos
        return pos, true
    }
    return -1, false
}

sst_remove :: proc(sst: ^SparseSet($N), entity: int) -> (int, bool) {
    if sst_has(sst, entity) {
        packed_i := sst.sparse[entity]
        sst.sparse[sst.packed[len(sst.packed) - 1]] = packed_i
        unordered_remove(&sst.packed, packed_i)
        return packed_i, true
    }
    return -1, false
}

sst_has :: proc(sst: ^SparseSet($N), entity: int) -> bool {
    return len(sst.packed) > 0 && sst.packed[sst.sparse[entity]] == entity
}

test :: proc() {
    {}
    cm : ComponentMap
    pos : Position = { 0, 0, 0 }
    append(&cm.Position, pos)

    da := make([dynamic]string)
    append(&da, "some data")
    test := cast(^runtime.Raw_Dynamic_Array)&da

    test2 := cast(^[dynamic]string)test
    fmt.println(test2[0])

    //sst : SparseSet(20)
    //sst_init(&sst)
    //if add_idx, add_ok := sst_add(&sst, 2); add_ok {
    //    fmt.println("added at", add_idx)
    //}
    //if r_idx, r_ok := sst_remove(&sst, 2); r_ok {
    //    fmt.println("removed at", r_idx)
    //}
    //fmt.println(sst_has(&sst, 2))
}
