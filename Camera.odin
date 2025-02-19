package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

CAMERA_PLAYER_Y_OFFSET :: 8
CAMERA_PLAYER_Z_OFFSET :: 16

Camera_State :: struct {
    position: [3]f32,
    target: [3]f32
}

move_camera :: proc(ps: Player_State, cs: ^Camera_State, elapsed_time: f64, delta_time: f32) {
    tgt_y := ps.position.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := ps.position.z + CAMERA_PLAYER_Z_OFFSET
    tgt : [3]f32 = {ps.position.x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(0.075))
    cs.target = ps.position
}

construct_camera_matrix :: proc(cs: ^Camera_State) -> matrix[4, 4]f32 {
    tgt := cs.target
    c_pos := cs.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

