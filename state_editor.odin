package main

import "constants"
import "core:math"
import "core:fmt"

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
    pos: [3]f32,
    displayed_attributes: #sparse[Level_Geometry_Component]bool,
    displayed_shape: i32,
    displayed_render_type: i32,
    save_dest: string
}

Connection :: struct {
    poss: [2][3]f32,
    dist: int
}

init_editor_state :: proc(es: ^Editor_State, level_to_load: string) {
    using constants
    es.y_rot = INIT_EDITOR_ROTATION 
    es.zoom = INIT_EDITOR_ZOOM
    es.save_dest = level_to_load
}

get_geometry_dist :: proc(ps: Physics_State, lga: Level_Geometry, lgb: Level_Geometry) -> (s0: [3]f32, s1: [3]f32, shortest_dist := max(f32)) {
    shape_data_a := ps.level_colliders[lga.shape]
    shape_data_b := ps.level_colliders[lgb.shape]
    mat_a := trans_to_mat4(lga.transform)
    mat_b := trans_to_mat4(lgb.transform)
    transformed_vertices_a := make([][3]f32, len(shape_data_a.vertices))
    defer delete(transformed_vertices_a)
    for v, vi in ps.level_colliders[lga.shape].vertices {
        transformed_vertices_a[vi] = (mat_a * [4]f32{v[0], v[1], v[2], 1.0}).xyz
    }
    transformed_vertices_b := make([][3]f32, len(shape_data_b.vertices))
    defer delete(transformed_vertices_b)
    for v, vi in ps.level_colliders[lgb.shape].vertices {
        transformed_vertices_b[vi] = (mat_b * [4]f32{v[0], v[1], v[2], 1.0}).xyz
    }
    indices_a := shape_data_a.indices
    indices_b := shape_data_b.indices
    len_a := len(shape_data_a.indices)
    len_b := len(shape_data_b.indices)
    for i := 0; i <= len_a - 3; i += 3 {
        tri_a := indices_a[i:i+3]
        tri_a_v0 := transformed_vertices_a[tri_a[0]]
        tri_a_v1 := transformed_vertices_a[tri_a[1]]
        tri_a_v2 := transformed_vertices_a[tri_a[2]]
        for j := 0; j <= len_b - 3; j += 3 {
            tri_b := indices_b[j:j+3]
            tri_b_v0 := transformed_vertices_b[tri_b[0]]
            tri_b_v1 := transformed_vertices_b[tri_b[1]]
            tri_b_v2 := transformed_vertices_b[tri_b[2]]
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
            encode_test_level_cbor(lgs^, es.save_dest)
            es.saved = true
        }
    } else {
        es.saved = false
    }
}

