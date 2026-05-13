package main

import "core:math"
import la "core:math/linalg"

update_camera :: proc(cs: ^Camera_State, pls: Player_State, gs: Game_State, triggers: Action_Triggers) {
    cts := pls.contact_state.state
    on_surface := cts == .ON_GROUND || cts == .ON_SLOPE

    cs.prev_position = cs.position
    cs.prev_target = cs.target

    // camera_mode := on_surface ? GROUND_CAMERA : AERIAL_CAMERA
    // pos_lerp := la.length(pls.velocity.xz) > FAST_CUTOFF ? camera_mode.high_speed_pos_lerp : camera_mode.pos_lerp
    camera_mode := TEST_CAMERA
    // pos_lerp := camera_mode.pos_lerp

    pos_tgt_y := pls.position.y + camera_mode.pos_offset.y + camera_mode.y_pos_mod * gs.intensity
    pos_tgt_z := pls.position.z + camera_mode.pos_offset.z + camera_mode.z_pos_mod * gs.intensity
    pos_tgt_x := pls.position.x + camera_mode.pos_offset.x

    // pos_tgt : [3]f32 = {pos_tgt_x, pos_tgt_y, pos_tgt_z}

    new_pos_x := math.lerp(cs.position.x, pos_tgt_x, f32(camera_mode.pos_lerp_x))
    new_pos_y := math.lerp(cs.position.y, pos_tgt_y, f32(camera_mode.pos_lerp_y))
    new_pos_z := math.lerp(cs.position.z, pos_tgt_z, f32(camera_mode.pos_lerp_z))
    new_pos: [3]f32 = {new_pos_x, new_pos_y, new_pos_z}

    camera_target := pls.position

    new_target: [3]f32

    new_target.y = math.lerp(cs.target.y, camera_target.y + camera_mode.tgt_y_offset + camera_mode.tgt_y_mod * gs.intensity, camera_mode.y_angle_lerp)
    new_target.x = math.lerp(cs.target.x, camera_target.x, camera_mode.x_angle_lerp)
    new_target.z = math.lerp(cs.target.z, camera_target.z, camera_mode.z_angle_lerp)

    fov_mod := camera_mode.fov_mod * gs.intensity
    new_fov := math.lerp(cs.fov, FOV + fov_mod, f32(0.1))

    if triggers.restart || triggers.checkpoint {
        new_pos = pls.position + camera_mode.pos_offset
        new_target = camera_target + [3]f32{0, camera_mode.tgt_y_offset, 0}
    }

    cs.position = new_pos
    cs.target   = new_target
    cs.fov      = new_fov
}
