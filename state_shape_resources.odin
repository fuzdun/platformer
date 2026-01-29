package main

import glm "core:math/linalg/glsl"

SHAPE_FILENAME := [SHAPE]string {
    .CUBE = "basic_cube",
    .CYLINDER = "cylinder",
    .ICO = "icosphere",
    .DASH_BARRIER = "dash_barrier",
    .SLIDE_ZONE = "slide_zone",
    .ICE_CREAM = "ice_cream_cone",
    .CHAIR = "chair",
    .BOUNCY = "basic_cube",
    .FRANK = "frank",
    .SPIN_TRAIL = "spin_trail"
}

SHAPE_NAME := [SHAPE]string {
    .CUBE = "CUBE",
    .CYLINDER = "CYLINDER",
    .ICO = "ICO",
    .DASH_BARRIER = "DASH_BARRIER",
    .SLIDE_ZONE = "SLIDE_ZONE",
    .ICE_CREAM = "ICE_CREAM",
    .CHAIR = "CHAIR",
    .BOUNCY = "BOUNCY",
    .FRANK = "FRANK",
    .SPIN_TRAIL = "SPIN_TRAIL"
}

TEXT_VERTICES :: [4]Quad_Vertex4 {
    {{-1, -1, 0, 1}, {0, 0}},
    {{1, -1, 0, 1}, {1, 0}},
    {{-1, 1, 0, 1}, {0, 1}},
    {{1, 1, 0, 1}, {1, 1}}
}

BACKGROUND_VERTICES :: [4]Quad_Vertex {
    {{-1, -1, -1}, {0, 0}},
    {{1, -1, -1}, {1, 0}},
    {{-1, 1, -1}, {0, 1}},
    {{1, 1, -1}, {1, 1}},
}

PARTICLE_VERTICES :: [4]Quad_Vertex {
    {{-0.7, -0.7, 0.0}, {0, 0}},
    {{0.7, -0.7, 0.0}, {1, 0}},
    {{-0.7, 0.7, 0.0}, {0, 1}},
    {{0.7, 0.7, 0.0}, {1, 1}},
}

Shape_Resources :: struct {
    player_vertices: []Vertex,
    player_outline_indices: []u32,
    player_fill_indices: []u32,

    level_geometry: [SHAPE]Shape_Data,

    vertex_offsets: Vertex_Offsets,
    index_offsets: Index_Offsets
}

Vertex :: struct{
    pos: glm.vec3,
    uv: glm.vec2,
    normal: glm.vec3
}

Shape_Data :: struct {
    vertices: []Vertex,
    indices: []u32
}

Char_Tex :: struct {
    id: u32,
    size: glm.ivec2,
    bearing: glm.ivec2,
    next: u32
}

Vertex_Offsets :: [len(SHAPE)]u32

Index_Offsets :: [len(SHAPE)]u32

free_shape_resources :: proc(sr: Shape_Resources) {
    delete(sr.player_vertices)
    delete(sr.player_fill_indices)
    delete(sr.player_outline_indices)
}

