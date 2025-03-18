package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

CAMERA_PLAYER_Y_OFFSET :: 80
CAMERA_PLAYER_Y_OFFSET_2 :: 160 
CAMERA_PLAYER_Z_OFFSET :: 180 
CAMERA_PLAYER_Z_OFFSET_2 :: 60 
CAMERA_PLAYER_X_OFFSET :: 0 

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
}

move_camera :: proc(ps: Player_State, cs: ^Camera_State, elapsed_time: f64, delta_time: f32) {
    bef_thresh := ps.prev_position.z >= -750 
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    tgt_y := ps.position.y + (bef_thresh ? CAMERA_PLAYER_Y_OFFSET : CAMERA_PLAYER_Y_OFFSET_2)
    tgt_z := ps.position.z + (bef_thresh ? CAMERA_PLAYER_Z_OFFSET : CAMERA_PLAYER_Z_OFFSET_2)
    tgt_x := ps.position.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(0.03))
    cs.target.x = math.lerp(cs.target.x, ps.position.x, f32(0.20))
    cs.target.y = math.lerp(cs.target.y, ps.position.y, f32(bef_thresh ? 0.07 : 0.20))
    cs.target.z = math.lerp(cs.target.z, ps.position.z, f32(bef_thresh ? 0.08 : 0.20))
}

interpolated_camera_matrix :: proc(cs: ^Camera_State, t: f32) -> glm.mat4{
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(.4, WIDTH / HEIGHT, 0.1, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

construct_camera_matrix :: proc(cs: ^Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(.4, WIDTH / HEIGHT, 0.1, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}


