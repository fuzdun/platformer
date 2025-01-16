package main
import glm "core:math/linalg/glsl"

Shape :: enum{ Triangle, InvertedPyramid, None }

Vertex :: struct{
    pos: glm.vec3,
    uv: glm.vec2
}
ShapeData :: struct{
    vertices: []Vertex,
    indices: []u16,
    outline_indices: []u16
}


@(rodata)
SHAPE_DATA := #partial [Shape]ShapeData{
    .Triangle = {
        {
            {{-0.5, -0.5, 0}, {0, 0}},
            {{0.5, -0.5, 0}, {1, 0}},
            {{0, 0.5, 0}, {0.5, 1}}
        },
        {
           0, 1, 2 
        },
        {
           0, 1, 2 
        }
    },
    .InvertedPyramid = {
        {
            {{-0.25, 0.25, -0.25}, {0, 0}},
            {{0, -0.25, 0},        {.5, .5}},
            {{0.25, 0.25, -0.25},  {0, 1}},
            {{0.25, 0.25, 0.25},   {1, 1}},
            {{-0.25, 0.25, 0.25},  {1, 0}},
        },
        {
            0, 1, 2,
            2, 1, 3,
            3, 1, 4,
            4, 1, 0,
            0, 2, 4,
            2, 3, 4
        },
        {
            0, 1, 2,
            2, 1, 3,
            3, 1, 4,
            4, 1, 0,
        }
    }
}
