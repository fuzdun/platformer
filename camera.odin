package main

import "core:math"
import glm "core:math/linalg/glsl"


CAMERA_PLAYER_Y_OFFSET :: 15
CAMERA_PLAYER_Z_OFFSET :: 40 
CAMERA_POS_LERP :: 0.03
CAMERA_X_LERP :: 0.20
CAMERA_Y_LERP :: 0.07
CAMERA_Z_LERP :: 0.15

// CAMERA_PLAYER_Y_OFFSET :: 00
// CAMERA_PLAYER_Z_OFFSET :: 20 
// CAMERA_POS_LERP :: 1.00
// CAMERA_X_LERP :: 1.00
// CAMERA_Y_LERP :: 1.00
// CAMERA_Z_LERP :: 1.00

CAMERA_PLAYER_X_OFFSET :: 0 

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
}

free_camera_state :: proc(cs: ^Camera_State) {}

interpolated_camera_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4{
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(1.0, WIDTH / HEIGHT, 10.0, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

construct_camera_matrix :: proc(cs: ^Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(.4, WIDTH / HEIGHT, 1.0, 10000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

