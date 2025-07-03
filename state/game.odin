package state

import la "core:math/linalg"

import enm "../enums"
import typ "../datatypes"

Game_State :: struct {
    level_geometry: Level_Geometry_State,
    input_state: Input_State,
    camera_state: Camera_State,
    editor_state: Editor_State,
    dirty_entities: [dynamic]int,
    time_mult: f32
}

free_gamestate :: proc(gs: ^Game_State) {
    delete_soa(gs.level_geometry)
    delete(gs.dirty_entities)
    free_editor_state(&gs.editor_state)
}

// AOS -> SOA
Level_Geometry_State :: #soa[dynamic]typ.Level_Geometry

Input_State :: struct {
    a_pressed: bool,
    d_pressed: bool,
    s_pressed: bool,
    w_pressed: bool,
    q_pressed: bool,
    c_pressed: bool,
    z_pressed: bool, 
    x_pressed: bool,
    lt_pressed: bool, 
    gt_pressed: bool,
    left_pressed: bool,
    right_pressed: bool,
    up_pressed : bool, 
    down_pressed: bool,
    pg_up_pressed: bool,
    pg_down_pressed: bool,
    tab_pressed: bool,
    bck_pressed: bool,
    e_pressed: bool,
    r_pressed: bool,
    ent_pressed: bool,
    spc_pressed: bool,
    hor_axis: f32,
    vert_axis: f32
}


Camera_State :: struct {
    position: [3]f32,
    target: [3]f32,
    prev_target: [3]f32,
    prev_position: [3]f32,
}

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
    connections: [dynamic]typ.Connection
}

free_editor_state :: proc(es: ^Editor_State) {
    delete(es.connections)
}

