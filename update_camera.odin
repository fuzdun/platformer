package main
import "core:math"


updated_camera_state :: proc(cs: Camera_State, player_pos: [3]f32) -> Camera_State {
    cs := cs 
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    tgt_y := player_pos.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := player_pos.z + CAMERA_PLAYER_Z_OFFSET
    tgt_x := player_pos.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(CAMERA_POS_LERP))
    cs.target.x = math.lerp(cs.target.x, player_pos.x, f32(CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, player_pos.y, f32(CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, player_pos.z, f32(CAMERA_Z_LERP))
    return cs
}


