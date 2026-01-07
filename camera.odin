package main

import "core:math"
import glm "core:math/linalg/glsl"

INIT_CAMERA_POS: [3]f32: {10, 60, 300} 
// INIT_CAMERA_POS: [3]f32: {300, 60, 500} 
CAMERA_PLAYER_X_OFFSET :: 0 
// CAMERA_PLAYER_X_OFFSET :: 20 
// CAMERA_PLAYER_Y_OFFSET :: 0 
CAMERA_PLAYER_Y_OFFSET :: 25
CAMERA_PLAYER_Z_OFFSET :: 19 
// CAMERA_PLAYER_Z_OFFSET :: 0

// CAMERA_PLAYER_X_OFFSET :: 0 
// CAMERA_PLAYER_Y_OFFSET :: 18
// CAMERA_PLAYER_Z_OFFSET :: 68 

CAMERA_POS_LERP :: 0.08
CAMERA_X_LERP :: 0.09
CAMERA_Y_LERP :: 0.08
CAMERA_Z_LERP :: 0.08

FOV :: 2.5
// FOV :: 1.0

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
}

interpolated_camera_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    proj := glm.mat4Perspective(FOV, WIDTH / HEIGHT, 1.0, 10000)
    return proj * view
}

construct_camera_matrix :: proc(cs: Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    proj := glm.mat4Perspective(FOV, WIDTH / HEIGHT, 1.0, 10000)
    return proj * view
}

only_projection_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    return glm.mat4Perspective(FOV, WIDTH / HEIGHT, 1.0, 10000)
}

only_view_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    return view
}

