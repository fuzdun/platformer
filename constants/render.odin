package constants

import glm "core:math/linalg/glsl"

import enm "../enums"
import typ "../datatypes"

PLAYER_PARTICLE_STACK_COUNT :: 5
PLAYER_PARTICLE_SECTOR_COUNT :: 10
PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2

I_MAT :: glm.mat4(1.0)

SHAPE_FILENAME := [enm.SHAPE]string {
    .CUBE = "basic_cube",
    .WEIRD = "weird"
}

TEXT_VERTICES :: [4]typ.Quad_Vertex4 {
    {{-1, -1, 0, 1}, {0, 0}},
    {{1, -1, 0, 1}, {1, 0}},
    {{-1, 1, 0, 1}, {0, 1}},
    {{1, 1, 0, 1}, {1, 1}}
}

BACKGROUND_VERTICES :: [4]typ.Quad_Vertex {
    {{-1, -1, -1}, {0, 0}},
    {{1, -1, -1}, {1, 0}},
    {{-1, 1, -1}, {0, 1}},
    {{1, 1, -1}, {1, 1}},
}

PARTICLE_VERTICES :: [4]typ.Quad_Vertex {
    {{-0.7, -0.7, 0.0}, {0, 0}},
    {{0.7, -0.7, 0.0}, {1, 0}},
    {{-0.7, 0.7, 0.0}, {0, 1}},
    {{0.7, 0.7, 0.0}, {1, 1}},
}
