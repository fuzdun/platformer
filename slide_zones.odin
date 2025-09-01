package main

Obb :: struct {
    id: int,
    center: [3]f32,
    axes: [3][3]f32,
    dim: [3]f32,
    transparency_t: f32
}

Slide_Zone_State :: struct {
    entities: #soa[dynamic]Obb,
    intersected: map[int]struct{},
    // last_intersected: map[int]struct{}
}

free_slide_zone_state :: proc(szs: ^Slide_Zone_State) {
    delete(szs.entities)
    delete_map(szs.intersected)
    // delete_map(szs.last_intersected)
}

