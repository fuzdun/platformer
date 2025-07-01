package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import st "state"

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

//Camera_State :: struct {
//    position: [3]f32,
//    target: [3]f32,
//    prev_target: [3]f32,
//    prev_position: [3]f32,
//}

move_camera :: proc(ps: Player_State, cs: ^st.Camera_State, elapsed_time: f64, delta_time: f32) {
    //bef_thresh := ps.prev_position.z >= -750 || ps.prev_position.y < - 950
    // bef_thresh := true
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    ppos := ps.position
    if ps.dashing {
        dash_t := (f32(elapsed_time) - ps.dash_time) / DASH_LEN
        dash_delta := ps.dash_end_pos - ps.dash_start_pos
        ppos = ps.dash_start_pos + dash_delta * dash_t
    }
    tgt_y := ppos.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := ppos.z + CAMERA_PLAYER_Z_OFFSET
    tgt_x := ppos.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(CAMERA_POS_LERP))
    cs.target.x = math.lerp(cs.target.x, ppos.x, f32(CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, ppos.y, f32(CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, ppos.z, f32(CAMERA_Z_LERP))
}

interpolated_camera_matrix :: proc(cs: ^st.Camera_State, t: f32) -> glm.mat4{
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(1.0, WIDTH / HEIGHT, 10.0, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

construct_camera_matrix :: proc(cs: ^st.Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(.4, WIDTH / HEIGHT, 1.0, 10000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}


