package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"


pressed_jump :: proc(did_bunny_hop: bool, z_pressed: bool, can_press_jump: bool, elapsed_time: f32) -> bool {
    return z_pressed && can_press_jump || did_bunny_hop 
}


ground_jumped :: proc(state: Player_States, pressed_jump: bool, left_ground_t: f32, elapsed_time: f32) -> bool {
    return pressed_jump && (state == .ON_GROUND || (f32(elapsed_time) - left_ground_t < COYOTE_TIME))
}


slope_jumped :: proc(state: Player_States, pressed_jump: bool, left_slope_t: f32, elapsed_time: f32) -> bool {
    return pressed_jump && (state == .ON_SLOPE || (f32(elapsed_time) - left_slope_t < COYOTE_TIME))
}


wall_jumped :: proc(state: Player_States, pressed_jump: bool, left_wall_t: f32, elapsed_time: f32) -> bool {
    return pressed_jump && (state == .ON_WALL || (f32(elapsed_time) - left_wall_t < COYOTE_TIME))
}


can_bunny_hop :: proc(debounce_t: f32, elapsed_time: f32) -> bool {
    return elapsed_time - debounce_t > BUNNY_DASH_DEBOUNCE
}


got_bunny_hop_input :: proc(touch_time: f32, jump_pressed_time: f32, slide_end_time: f32, elapsed_time: f32) -> bool {
    surface_touch_diff := math.abs(touch_time - jump_pressed_time)
    slide_end_diff := math.abs(slide_end_time - jump_pressed_time)
    return (
        (surface_touch_diff < BUNNY_WINDOW) ||
        (slide_end_diff < BUNNY_WINDOW && elapsed_time - jump_pressed_time < BUNNY_WINDOW)
    )
}


did_bunny_hop :: proc(dash_hop_debounce_t: f32, touch_time: f32, jump_pressed_time: f32, slide_end_time: f32, elapsed_time: f32) -> bool {
    return can_bunny_hop(dash_hop_debounce_t, elapsed_time) && got_bunny_hop_input(touch_time, jump_pressed_time, slide_end_time, elapsed_time)
}


jumped :: proc(ground_jumped: bool, slope_jumped: bool, wall_jumped: bool, did_bunny_hop: bool, elapsed_time: f32) -> bool {
    return ground_jumped || slope_jumped || wall_jumped || did_bunny_hop
}


on_surface :: proc(state: Player_States) -> bool {
    return state == .ON_GROUND || state == .ON_SLOPE || state == .ON_WALL
}


input_dir :: proc(is: Input_State) -> [2]f32 {
    input_x: f32 = 0.0
    input_z: f32 = 0.0
    if is.left_pressed do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed do input_z -= 1
    if is.down_pressed do input_z += 1
    input_dir := la.normalize0([2]f32{input_x, input_z})
    if is.hor_axis !=0 || is.vert_axis != 0 {
        input_dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    }
    return input_dir
}


