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
}

