package main

import "core:math"


OBJ_MOVE_SPD :: 100.0
OBJ_ROT_SPD :: 2.0
OBJ_SCALE_SPD :: 1.0
CAM_ROT_SPD :: 0.055

MAX_DRAW_GEOMETRY_DIST :: 300
MAX_DRAW_GEOMETRY_DIST2 :: MAX_DRAW_GEOMETRY_DIST * MAX_DRAW_GEOMETRY_DIST

GUIDELINE_LEN :: 200
GUIDELINE_COL: [3]f32 : {0.5, 0, 0.5}

SPAWN_MARKER_LEN :: 20
SPAWN_MARKER_COL: [3]f32 : {0, 1, 0}

GRID_LINES :: 100
GRID_LEN :: 10000
GRID_COL: [3]f32 : {.75, .75, .75}

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
    connections: [dynamic]Connection,
    pos: [3]f32
}

free_editor_state :: proc(es: ^Editor_State) {
    delete(es.connections)
}

Connection :: struct {
    poss: [2][3]f32,
    dist: int
}

get_geometry_dist :: proc(ps: Physics_State, lga: Level_Geometry, lgb: Level_Geometry) -> (s0: [3]f32, s1: [3]f32, shortest_dist := max(f32)) {
    shape_data_a := ps.level_colliders[lga.shape]
    shape_data_b := ps.level_colliders[lgb.shape]
    mat_a := trans_to_mat4(lga.transform)
    mat_b := trans_to_mat4(lgb.transform)
    vertices_a := make([][3]f32, len(shape_data_a.vertices))
    defer delete(vertices_a)
    vertices_b := make([][3]f32, len(shape_data_b.vertices))
    defer delete(vertices_b)
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

remove_geometry :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, ps: ^Physics_State, rs: ^Render_State, es: ^Editor_State) {
    ordered_remove_soa(&lgs.entities, es.selected_entity) 
    es.selected_entity = max(0, min(len(lgs.entities) - 1, es.selected_entity - 1))
    editor_reload_level_geometry(lgs, sr, ps, rs)
}

add_geometry :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, ps: ^Physics_State, rs: ^Render_State, es: ^Editor_State, lg_in: Level_Geometry) {
    lg := lg_in
    es.selected_entity = len(lgs.entities)
    append(&lgs.entities, lg)
    editor_reload_level_geometry(lgs, sr, ps, rs)
}

