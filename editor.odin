package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"
import "core:slice"

OBJ_MOVE_SPD :: 30.0
OBJ_ROT_SPD :: 1.0
OBJ_SCALE_SPD :: 0.3

SSBO_Registry :: [len(SHAPES) * len(ProgramName)][dynamic]int

Editor_State :: struct {
    selected_entity: int,
    saved: bool,
    can_add: bool,
    can_delete: bool,
    can_switch: bool,
    can_swap: bool,
    x_rot: f32,
    y_rot: f32,
    zoom: f32,
    ssbo_registry: SSBO_Registry
}

editor_move_camera :: proc(lgs: ^Level_Geometry_State, es: ^Editor_State, cs: ^Camera_State, delta_time: f32) {
    rot_mat := la.matrix4_from_euler_angles(es.x_rot, es.y_rot, 0, .YXZ)
    selfie_stick := rot_mat * [4]f32{0, 0, es.zoom, 1}
    lg := lgs[es.selected_entity]
    cs.target = lg.transform.position.xyz
    tgt := lg.transform.position + selfie_stick.xyz
    cs.position = math.lerp(cs.position, tgt, f32(0.075))
}

editor_move_object :: proc(gs: ^Game_State, es: ^Editor_State, is: Input_State, rs: ^Render_State, delta_time: f32) {
    lgs := &gs.level_geometry
    selected_obj := &lgs[es.selected_entity]
    rotating := is.r_pressed
    scaling := is.e_pressed
    
    rot_x, rot_y, rot_z := la.euler_angles_xyz_from_quaternion(selected_obj.transform.rotation)
    if is.q_pressed && es.can_add {
        rotation: quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
        position: Position = lgs[es.selected_entity].transform.position
        new_lg: Level_Geometry
        new_lg.shape = .CUBE
        new_lg.collider = .CUBE 
        new_lg.transform = {position,{5, 5, 5}, rotation}
        new_lg.shaders = {.Trail}
        new_lg.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
        for &idx in new_lg.ssbo_indexes {
            idx = -1
        }
        add_geometry(gs, rs, es, new_lg)
    }
    es.can_add = !is.q_pressed

    if (is.lt_pressed || is.gt_pressed)&& es.can_swap {

        // do shape swap

        //sn := SHAPES
        //cur_shape_idx := 0
        //for name, idx in SHAPES {
        //    if name == selected_obj.shape {
        //        cur_shape_idx = int(idx)
        //        break
        //    }
        //}
        //nxt_shape := math.abs((is.lt_pressed ? cur_shape_idx - 1 : cur_shape_idx + 1) % len(SHAPES))
        //selected_obj.shape = SHAPES(nxt_shape)
        //selected_obj.collider = SHAPES(nxt_shape)
    }
    es.can_swap = !(is.lt_pressed || is.gt_pressed)

    if is.bck_pressed && es.can_delete {
        remove_geometry(lgs, rs, es)
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
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.up_pressed {
        if rotating {
            rot_x -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.z += 0.1;
        } else {
            selected_obj.transform.position.z -=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.down_pressed {
        if rotating {
            rot_x += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.z -= 0.1;
        } else {
            selected_obj.transform.position.z +=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.left_pressed {
        if rotating {
            rot_z += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.x -= 0.1;
        } else {
            selected_obj.transform.position.x -=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.right_pressed {
        if rotating {
            rot_z -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.x += 0.1;
        } else {
            selected_obj.transform.position.x +=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.pg_up_pressed {
        if rotating {
            rot_y -= OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.y += 0.1;
        } else {
            selected_obj.transform.position.y +=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.pg_down_pressed {
        if rotating {
            rot_y += OBJ_ROT_SPD * delta_time
            selected_obj.transform.rotation = la.quaternion_from_euler_angles_f32(rot_x, rot_y, rot_z, .XYZ)
        } else if scaling {
            selected_obj.transform.scale.y -= 0.1;
        } else {
            selected_obj.transform.position.y -=  OBJ_MOVE_SPD * delta_time
        }
        append(&gs.dirty_entities, es.selected_entity)
    }
    if is.a_pressed {
        es.x_rot -= .01
    }
    if is.d_pressed {
        es.x_rot += .01
    }
    if is.s_pressed {
        es.y_rot += .01
    }
    if is.w_pressed {
        es.y_rot -= .01
    }
    if is.z_pressed {
        es.zoom = es.zoom + 5
    }
    if is.x_pressed {
        es.zoom = max(0, es.zoom - 5)
    }
    if is.tab_pressed && es.can_switch {
        es.selected_entity = (es.selected_entity + 1) % len(lgs)
    }

    es.can_switch = !is.tab_pressed
}

editor_save_changes :: proc(lgs:^Level_Geometry_State, is: Input_State, es: ^Editor_State) {
    if is.ent_pressed {
        if !es.saved {
            encode_test_level_cbor(lgs)
            es.saved = true
        }
    } else {
        es.saved = false
    }
}

remove_geometry :: proc(lgs: ^Level_Geometry_State, rs: ^Render_State, es: ^Editor_State) {
    lg := lgs[es.selected_entity]
    for shader in lg.shaders {
        group_idx := int(shader) * len(SHAPES) + int(lg.shape)
        registry := es.ssbo_registry[group_idx]
        idx_in_render_group, found := slice.binary_search(registry[:], es.selected_entity)
        if found {
            for lg_idx in registry[idx_in_render_group + 1:] {
                lgs[lg_idx].ssbo_indexes[shader] -= 1
                
            }
            ssbo_idx := int(rs.render_group_offsets[group_idx]) + idx_in_render_group
            ordered_remove(&rs.static_transforms, ssbo_idx)
            ordered_remove(&rs.z_widths, ssbo_idx)
            for &g_offset, idx in rs.render_group_offsets[group_idx + 1:] {
                g_offset -= 1 
            }
        }
    }
    ordered_remove_soa(lgs, es.selected_entity) 
    es.selected_entity = min(len(lgs) - 1, es.selected_entity)
}

add_geometry :: proc(gs: ^Game_State, rs: ^Render_State, es: ^Editor_State, lg_in: Level_Geometry) {
    lg := lg_in
    //lg_idx := len(gs.level_geometry)
    es.selected_entity = len(gs.level_geometry)
    for shader in lg.shaders {
        last_group_idx := len(rs.render_group_offsets) - 1
        group_idx := int(int(shader) * len(SHAPES) + int(lg.shape))
        in_last_group := group_idx == last_group_idx
        nxt_group_idx := in_last_group ? u32(len(rs.static_transforms)) : rs.render_group_offsets[group_idx + 1]

        append(&es.ssbo_registry[group_idx], es.selected_entity)
        lg.ssbo_indexes[shader] = int(nxt_group_idx)

        for &g_offset, idx in rs.render_group_offsets[group_idx + 1:] {
            g_offset += 1 
        }
    }
    append(&gs.level_geometry, lg)
    append(&gs.dirty_entities, es.selected_entity)
}

