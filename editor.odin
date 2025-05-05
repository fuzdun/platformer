package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"
import "core:slice"

OBJ_MOVE_SPD :: 30.0
OBJ_ROT_SPD :: 1.0
OBJ_SCALE_SPD :: 0.3
MAX_DRAW_GEOMETRY_DIST :: 1000
MAX_DRAW_GEOMETRY_DIST2 :: MAX_DRAW_GEOMETRY_DIST * MAX_DRAW_GEOMETRY_DIST

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
    connections: [dynamic][3]f32
}

get_selected_geometry_dists :: proc(es: ^Editor_State, ps: Physics_State, lgs: Level_Geometry_State) {
    clear(&es.connections)
    selected_geometry := lgs[es.selected_entity]
    for lg, idx in lgs {
        if idx == es.selected_entity {
            continue
        } 
        lg_dist := la.length2(selected_geometry.transform.position - lg.transform.position)
        if lg_dist > MAX_DRAW_GEOMETRY_DIST2 {
            continue
        }
        fmt.println("should draw")
        s0, s1, dist := get_geometry_dist(ps, selected_geometry, lg)
        append(&es.connections, s0, s1)
    }
}

get_geometry_dist :: proc(ps: Physics_State, lga: Level_Geometry, lgb: Level_Geometry) -> (s0: [3]f32, s1: [3]f32, shortest_dist := max(f32)) {
    shape_data_a := ps.level_colliders[lga.shape]
    shape_data_b := ps.level_colliders[lgb.shape]
    mat_a := trans_to_mat4(lga.transform)
    mat_b := trans_to_mat4(lgb.transform)
    vertices_a := make([][3]f32, len(shape_data_a.vertices))
    vertices_b := make([][3]f32, len(shape_data_b.vertices))
    lg_get_transformed_collider_vertices(lga, mat_a, ps, vertices_a)
    lg_get_transformed_collider_vertices(lgb, mat_b, ps, vertices_b)

    indices_a := shape_data_a.indices
    indices_b := shape_data_b.indices
    len_a := len(shape_data_a.indices)
    len_b := len(shape_data_b.indices)
    for i := 0; i <= len_a - 3; i += 3 {
        tri_a := indices_a[i:i+3]
        tri_a_v0 := vertices_a[tri_a[0]]
        tri_a_v1 := vertices_a[tri_a[1]]
        tri_a_v2 := vertices_a[tri_a[2]]
        for j := 0; j <= len_b - 3; j += 3 {
            tri_b := indices_b[j:j+3]
            tri_b_v0 := vertices_b[tri_b[0]]
            tri_b_v1 := vertices_b[tri_b[1]]
            tri_b_v2 := vertices_b[tri_b[2]]
            c0, c1, dist := closest_triangle_connection(tri_a_v0, tri_a_v1, tri_a_v2, tri_b_v0, tri_b_v1, tri_b_v2)
            if dist < shortest_dist {
                shortest_dist = dist
                s0 = c0
                s1 = c1
            }
        }
    }
    shortest_dist = math.sqrt(shortest_dist)
    return
}

editor_move_camera :: proc(lgs: ^Level_Geometry_State, es: ^Editor_State, cs: ^Camera_State, delta_time: f32) {
    rot_mat := la.matrix4_from_euler_angles(es.x_rot, es.y_rot, 0, .YXZ)
    selfie_stick := rot_mat * [4]f32{0, 0, es.zoom, 1}
    lg := lgs[es.selected_entity]
    cs.target = lg.transform.position.xyz
    tgt := lg.transform.position + selfie_stick.xyz
    cs.position = math.lerp(cs.position, tgt, f32(0.075))
}

editor_move_object :: proc(gs: ^Game_State, es: ^Editor_State, is: Input_State, ps: ^Physics_State, rs: ^Render_State, delta_time: f32) {
    lgs := &gs.level_geometry
    selected_obj := &lgs[es.selected_entity]
    rotating := is.r_pressed
    scaling := is.e_pressed
    
    rot_x, rot_y, rot_z := la.euler_angles_xyz_from_quaternion(selected_obj.transform.rotation)
    if is.q_pressed && es.can_add {
        cur_shape := selected_obj.shape
        rotation: quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
        // rotation: quaternion128 = selected_obj.transform
        position: Position = lgs[es.selected_entity].transform.position
        new_lg: Level_Geometry
        new_lg.shape = cur_shape
        new_lg.collider = cur_shape 
        // new_lg.transform = {position,{5, 5, 5}, rotation}
        new_lg.transform = selected_obj.transform
        new_lg.shaders = {.Trail}
        new_lg.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
        for &idx in new_lg.ssbo_indexes {
            idx = -1
        }
        add_geometry(gs, ps, rs, es, new_lg)
    }
    es.can_add = !is.q_pressed

    if (is.lt_pressed || is.gt_pressed) && es.can_swap {
        cur_shape_idx := int(selected_obj.shape)
        nxt_shape := 0
        if is.lt_pressed {
            nxt_shape = cur_shape_idx == 0 ? len(SHAPES) - 1 : cur_shape_idx - 1
        } else {
            nxt_shape = (cur_shape_idx + 1) % len(SHAPES)
        }
        new_lg := selected_obj^
        new_lg.shape = SHAPES(nxt_shape)
        new_lg.collider = SHAPES(nxt_shape)
        ordered_remove_soa(&gs.level_geometry, es.selected_entity) 
        append(&gs.level_geometry, new_lg)
        // es.selected_entity = 0
        es.selected_entity = len(gs.level_geometry) - 1
        fmt.println(es.selected_entity)
        editor_reload_level_geometry(gs, ps, rs)
    }
    es.can_swap = !(is.lt_pressed || is.gt_pressed)

    if is.bck_pressed && es.can_delete {
        remove_geometry(gs, ps, rs, es)
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

remove_geometry :: proc(gs: ^Game_State, ps: ^Physics_State, rs: ^Render_State, es: ^Editor_State) {
    ordered_remove_soa(&gs.level_geometry, es.selected_entity) 
    es.selected_entity = max(0, min(len(gs.level_geometry) - 1, es.selected_entity - 1))
    editor_reload_level_geometry(gs, ps, rs)
}

add_geometry :: proc(gs: ^Game_State, ps: ^Physics_State, rs: ^Render_State, es: ^Editor_State, lg_in: Level_Geometry) {
    // fmt.println("before:", gs.level_geometry)
    // cur_shape_idx := int(selected_obj.shape)
    lg := lg_in
    es.selected_entity = len(gs.level_geometry)
    append(&gs.level_geometry, lg)
    editor_reload_level_geometry(gs, ps, rs)
    // fmt.println("before:", gs.level_geometry)
}

