package main

import "core:math"
import "core:fmt"
import glm "core:math/linalg/glsl"

INIT_CAMERA_POS: [3]f32: {10, 60, 300} 
// INIT_CAMERA_POS: [3]f32: {300, 60, 500} 
CAMERA_PLAYER_X_OFFSET :: 0 
// CAMERA_PLAYER_X_OFFSET :: 20 
// CAMERA_PLAYER_Y_OFFSET :: 0 
CAMERA_PLAYER_Y_OFFSET :: 10
CAMERA_PLAYER_Z_OFFSET :: 25 
// CAMERA_PLAYER_Z_OFFSET :: 0

// CAMERA_PLAYER_X_OFFSET :: 0 
// CAMERA_PLAYER_Y_OFFSET :: 18
// CAMERA_PLAYER_Z_OFFSET :: 68 

CAMERA_POS_LERP :: 0.10
CAMERA_X_LERP :: 0.07
CAMERA_Y_POS_LERP :: 0.1
CAMERA_Y_NEG_LERP :: 0.07
CAMERA_Z_LERP :: 0.08

FOV :: 2.0
EDITOR_FOV :: 1.0

Camera_Mode :: struct {
    pos_offset: [3]f32,
    pos_lerp: f32,
    high_speed_pos_lerp: f32,
    x_angle_lerp: f32,
    // y_angle_lerp_rising: f32,
    // y_angle_lerp_falling: f32,
    y_angle_lerp: f32,
    z_angle_lerp: f32,
    tgt_y_offset: f32,
    fov_mod: f32
}

GROUND_CAMERA: Camera_Mode: {
    pos_offset = {0, 15, 25},
    pos_lerp = 0.07,
    high_speed_pos_lerp = 0.095,
    x_angle_lerp = 0.07,
    // y_angle_lerp_rising = 0.07,
    // y_angle_lerp_falling = 0.1,
    y_angle_lerp = 0.07,
    z_angle_lerp = 0.08,
    tgt_y_offset = 9.0,
    fov_mod = 1.0
}

AERIAL_CAMERA: Camera_Mode: {
    pos_offset = {0, 10, 9.0},
    // pos_offset = {0, 10, 25},
    pos_lerp = 0.07,
    high_speed_pos_lerp = 0.085,
    x_angle_lerp = 0.09,
    // y_angle_lerp_rising = 0.07,
    // y_angle_lerp_falling = 0.1,
    y_angle_lerp = 0.09,
    z_angle_lerp = 0.08,
    tgt_y_offset = 6.0,
    // tgt_y_lerp = 0.1,
    fov_mod = 1.2
}

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
    // y_offset: f32,
    y_lerp: f32,
    fov: f32,
}

interpolated_camera_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    c_dir := glm.normalize(c_pos - tgt)
    up: [3]f32 = {0, 1, 0}
    c_right := glm.normalize(glm.cross(up, c_dir))
    c_up := glm.normalize(glm.cross(c_dir, c_right))
    view := glm.mat4LookAt(c_pos, tgt, up)
    proj := glm.mat4Perspective(EDIT ? EDITOR_FOV : cs.fov, WIDTH / HEIGHT, 1.0, 10000)
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
    proj := glm.mat4Perspective(EDIT ? EDITOR_FOV : cs.fov, WIDTH / HEIGHT, 1.0, 10000)
    return proj * view
}

only_projection_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4 {
    return glm.mat4Perspective(EDIT ? EDITOR_FOV : cs.fov, WIDTH / HEIGHT, 1.0, 10000)
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

