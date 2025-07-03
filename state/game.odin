package state

import la "core:math/linalg"
import enm "enums"

CAMERA_PLAYER_X_OFFSET :: 0 
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

free_editor_state :: proc(es: ^Editor_State) {
    delete(es.connections)
}

// AOS -> SOA
Level_Geometry_State :: #soa[dynamic]Level_Geometry

Level_Geometry :: struct {
    transform: Transform,
    angular_velocity: la.Vector3f32,
    shape: enm.SHAPE,
    collider: Collider,
    shaders: Active_Shaders,
    attributes: Level_Geometry_Attributes,
    aabb: AABB,
    ssbo_indexes: [enm.ProgramName]int
}

Transform :: struct{
    position: Position,
    scale: Scale,
    rotation: Rotation
}
Position :: la.Vector3f32 
Scale :: la.Vector3f32
Rotation :: quaternion128
make_transform :: proc(
    position: Position = {0, 0, 0},
    scale: Scale = {1, 1, 1},
    rotation: Rotation = quaternion(real=0, imag=0, jmag=0, kmag=0)
) -> Transform {
    return {position, scale, rotation}
}

Angular_Velocity :: la.Vector3f32
Shape :: enm.SHAPE
Collider :: enm.SHAPE
Active_Shaders :: bit_set[enm.ProgramName; u64]
Level_Geometry_Attributes :: bit_set[Level_Geometry_Component_Name; u64]
AABB :: struct{
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32
}

Level_Geometry_Component_Name :: enum {
    Transform = 0,
    Shape = 1,
    Collider = 2,
    Active_Shaders = 3,
    Angular_Velocity = 4 
}

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
    connections: [dynamic]Connection
}

Connection :: struct {
    poss: [2][3]f32,
    dist: int
}

