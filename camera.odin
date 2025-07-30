package main

import "core:math"
import glm "core:math/linalg/glsl"


CAMERA_PLAYER_Y_OFFSET :: 20
CAMERA_PLAYER_Z_OFFSET :: 40 
CAMERA_POS_LERP :: 0.03
// CAMERA_POS_LERP :: 0.004
CAMERA_X_LERP :: 0.15
//CAMERA_X_LERP :: 0.015
CAMERA_Y_LERP :: 0.07
CAMERA_Z_LERP :: 0.15

 //CAMERA_PLAYER_Y_OFFSET :: 3 
 //CAMERA_PLAYER_Z_OFFSET :: 6 
 //CAMERA_POS_LERP :: 1.00
 //CAMERA_X_LERP :: 1.00
 //CAMERA_Y_LERP :: 1.00
 //CAMERA_Z_LERP :: 1.00

CAMERA_PLAYER_X_OFFSET :: 0 

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
}

free_camera_state :: proc(cs: ^Camera_State) {}

interpolated_camera_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    proj := glm.mat4Perspective(1.0, WIDTH / HEIGHT, 1.0, 10000)
    return proj * view
}

construct_camera_matrix :: proc(cs: ^Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    proj := glm.mat4Perspective(1.5, WIDTH / HEIGHT, 1.0, 10000)
    return proj * view
}

only_projection_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    return glm.mat4Perspective(1.0, WIDTH / HEIGHT, 10.0, 10000)
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

