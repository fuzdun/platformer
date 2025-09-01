package main

Obb :: struct {
    center: [3]f32,
    axes: [3][3]f32,
    dim: [3]f32
}

Slide_Zone_State :: [dynamic]Obb

free_slide_zone_state :: proc(szs: Slide_Zone_State) {
    delete(szs)
}

