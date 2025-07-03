package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

import st "state"
import const "state/constants"

move_camera :: proc(ps: st.Player_State, cs: ^st.Camera_State, elapsed_time: f64, delta_time: f32) {
    //bef_thresh := ps.prev_position.z >= -750 || ps.prev_position.y < - 950
    // bef_thresh := true
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    ppos := ps.position
    if ps.dashing {
        dash_t := (f32(elapsed_time) - ps.dash_time) / const.DASH_LEN
        dash_delta := ps.dash_end_pos - ps.dash_start_pos
        ppos = ps.dash_start_pos + dash_delta * dash_t
    }
    tgt_y := ppos.y + const.CAMERA_PLAYER_Y_OFFSET
    tgt_z := ppos.z + const.CAMERA_PLAYER_Z_OFFSET
    tgt_x := ppos.x + const.CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(const.CAMERA_POS_LERP))
    cs.target.x = math.lerp(cs.target.x, ppos.x, f32(const.CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, ppos.y, f32(const.CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, ppos.z, f32(const.CAMERA_Z_LERP))
}

interpolated_camera_matrix :: proc(cs: ^st.Camera_State, t: f32) -> glm.mat4{
    tgt := math.lerp(cs.prev_target, cs.target, t)
    c_pos := math.lerp(cs.prev_position, cs.position, t)
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(1.0, const.WIDTH / const.HEIGHT, 10.0, 1000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}

construct_camera_matrix :: proc(cs: ^st.Camera_State) -> glm.mat4 {
    tgt := cs.target
    c_pos := cs.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(tgt.x - c_pos.x), f32(tgt.y - c_pos.y), f32(tgt.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(.4, const.WIDTH / const.HEIGHT, 1.0, 10000)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})
    return proj * rot * offset
}


