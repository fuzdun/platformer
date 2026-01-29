package main

import la "core:math/linalg"


Input_Attributes :: struct {
    jump_pressed: bool,
    action_pressed: bool,
    spin_pressed: bool,
    restart_pressed: bool,
    dir: [2]f32,
}

get_input_attributes :: proc(
    is: Input_State,
    elapsed_time: f32,
    delta_time: f32
) -> (out: Input_Attributes) {
    out.jump_pressed = is.z_pressed
    out.action_pressed = is.x_pressed
    out.spin_pressed = is.c_pressed
    out.restart_pressed = is.r_pressed

    input_x: f32
    input_z: f32
    if is.left_pressed  do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed    do input_z -= 1
    if is.down_pressed  do input_z += 1

    if is.hor_axis != 0 || is.vert_axis != 0 {
        out.dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    } else {
        out.dir = la.normalize0([2]f32{input_x, input_z})
    }
    return
}
