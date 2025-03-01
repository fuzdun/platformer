package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"

OBJ_MOVE_SPD :: 30.0
OBJ_ROT_SPD :: 1.0
OBJ_SCALE_SPD :: 0.3

Editor_State :: struct {
    selected_entity: int,
    saved: bool,
    can_add: bool,
    can_delete: bool,
    can_switch: bool
}

editor_move_camera :: proc(lgs: ^Level_Geometry_State, es: ^Editor_State, cs: ^Camera_State, delta_time: f32) {
    lg := lgs[es.selected_entity]
    cs.target = lg.transform.position.xyz
    tgt_y := lg.transform.position.y + 20
    tgt_z := lg.transform.position.z + 100 
    tgt : [3]f32 = {lg.transform.position.x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(0.075))
}

editor_move_object :: proc(lgs: ^Level_Geometry_State, es: ^Editor_State, is: Input_State, delta_time: f32) {
    selected_obj := &lgs[es.selected_entity]
    rotating := is.r_pressed
    scaling := is.e_pressed
    
    rot_x, rot_y, rot_z := la.euler_angles_xyz_from_quaternion(selected_obj.transform.rotation)
    if is.q_pressed && es.can_add {
        rotation: quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
        position: Position = lgs[es.selected_entity].transform.position
        new_cube: Level_Geometry
        new_cube.shape = "basic_cube"
        new_cube.collider = "basic_cube"
        new_cube.transform = {position,{5, 5, 5}, rotation}
        new_cube.shaders = {.Trail}
        new_cube.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
        append(lgs, new_cube)
        es.selected_entity = len(lgs) - 1
    }
    es.can_add = !is.q_pressed

    if is.bck_pressed && es.can_delete {
        ordered_remove_soa(lgs, es.selected_entity) 
        es.selected_entity = min(len(lgs) - 1, es.selected_entity)
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

