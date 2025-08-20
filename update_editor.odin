package main

import "core:math"
import la "core:math/linalg"

editor_update :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, es: ^Editor_State, cs: ^Camera_State, is: Input_State, rs: ^Render_State, phs: ^Physics_State, delta_time: f32) {
    // get selected geometry distances
    clear(&es.connections)
    selected_geometry := lgs.entities[es.selected_entity]
    if is.c_pressed {
        for lg, idx in lgs.entities {
            if idx == es.selected_entity {
                continue
            } 
            lg_dist := la.length2(selected_geometry.transform.position - lg.transform.position)
            if lg_dist > MAX_DRAW_GEOMETRY_DIST2 {
                continue
            }
            s0, s1, dist := get_geometry_dist(phs^, selected_geometry, lg)
            append(&es.connections, Connection{{s0, s1}, int(abs(dist))})
        }
    }

    // move camera
    rot_mat := la.matrix4_from_euler_angles(es.x_rot, es.y_rot, 0, .YXZ)
    selfie_stick := rot_mat * [4]f32{0, 0, es.zoom, 1}
    lg := lgs.entities[es.selected_entity]
    cs.target = lg.transform.position.xyz
    es.pos = lg.transform.position.xyz
    tgt := lg.transform.position + selfie_stick.xyz
    cs.position = math.lerp(cs.position, tgt, f32(0.075))

    // update selected object
    selected_obj := &lgs.entities[es.selected_entity]
    rotating := is.r_pressed
    scaling := is.e_pressed

    proj_mat := construct_camera_matrix(cs^)
    camera_right_vec: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
    camera_right_vec = la.normalize(camera_right_vec)
    camera_up_vec: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
    camera_up_vec = la.normalize(camera_up_vec)
    camera_fwd_vec := la.normalize(la.cross(camera_up_vec, camera_right_vec))

    fwd_move_vec := is.alt_pressed ? camera_fwd_vec : [3]f32{0, 0, -1}
    right_move_vec := is.alt_pressed ? camera_right_vec : [3]f32{1, 0, 0}
    up_move_vec := is.alt_pressed ? camera_up_vec : [3]f32{0, 1, 0}
    
    rot_x, rot_y, rot_z := la.euler_angles_xyz_from_quaternion(selected_obj.transform.rotation)
    if is.q_pressed && es.can_add {
        cur_shape := selected_obj.shape
        new_lg: Level_Geometry
        new_lg.shape = cur_shape
        new_lg.collider = cur_shape 
        new_lg.transform = selected_obj.transform
        // new_lg.shaders = {.Level_Geometry_Fill}
        new_lg.render_type = .Standard
        new_lg.attributes = { .Collider }
        add_geometry(lgs, sr, phs, rs, es, new_lg)
    }
    es.can_add = !is.q_pressed

    if (is.lt_pressed || is.gt_pressed) && es.can_swap {
        cur_shape_idx := int(selected_obj.shape)
        nxt_shape := 0
        if is.lt_pressed {
            nxt_shape = cur_shape_idx == 0 ? len(SHAPE) - 1 : cur_shape_idx - 1
        } else {
            nxt_shape = (cur_shape_idx + 1) % len(SHAPE)
        }
        new_lg := selected_obj^
        new_lg.shape = SHAPE(nxt_shape)
        new_lg.collider = SHAPE(nxt_shape)
        ordered_remove_soa(&lgs.entities, es.selected_entity) 
        append(&lgs.entities, new_lg)
        es.selected_entity = len(lgs.entities) - 1
        editor_reload_level_geometry(lgs, sr, phs, rs)
    }
    es.can_swap = !(is.lt_pressed || is.gt_pressed)

    if is.bck_pressed && es.can_delete {
        remove_geometry(lgs, sr, phs, rs, es)
    }
    es.can_delete = !is.bck_pressed

    if is.spc_pressed {
        if rotating {
            rot_x = 0
            rot_y = 0
            rot_z = 0
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale = {20, 20, 20}
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.up_pressed {
        if rotating {
            rot_x -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.z += OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position +=  OBJ_MOVE_SPD * fwd_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.down_pressed {
        if rotating {
            rot_x += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.z -= OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position -=  OBJ_MOVE_SPD * fwd_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.left_pressed {
        if rotating {
            rot_z += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.x -= OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position -= OBJ_MOVE_SPD * right_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.right_pressed {
        if rotating {
            rot_z -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.x += OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position += OBJ_MOVE_SPD * right_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.pg_up_pressed {
        if rotating {
            rot_y -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.y += OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position +=  OBJ_MOVE_SPD * up_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.pg_down_pressed {
        if rotating {
            rot_y += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.y -= OBJ_SCALE_SPD;
        } else {
            selected_obj.transform.position -=  OBJ_MOVE_SPD * up_move_vec * delta_time
        }
        append(&lgs.dirty_entities, es.selected_entity)
    }
    if is.a_pressed {
        es.x_rot -= CAM_ROT_SPD
    }
    if is.d_pressed {
        es.x_rot += CAM_ROT_SPD
    }
    if is.s_pressed {
        es.y_rot += CAM_ROT_SPD
    }
    if is.w_pressed {
        es.y_rot -= CAM_ROT_SPD
    }
    if is.z_pressed {
        es.zoom = es.zoom + 5
    }
    if is.x_pressed {
        es.zoom = max(0, es.zoom - 5)
    }
    if is.tab_pressed && es.can_switch {
        if is.lshift_pressed {
            nxt_selected_entity := es.selected_entity - 1
            es.selected_entity = nxt_selected_entity < 0 ? len(lgs.entities) - 1 : nxt_selected_entity
        } else {
            es.selected_entity = (es.selected_entity + 1) % len(lgs.entities)
        }
    }
    if is.ent_pressed {
        if !es.saved {
            encode_test_level_cbor(lgs)
            es.saved = true
        }
    } else {
        es.saved = false
    }

    es.can_switch = !is.tab_pressed
}

