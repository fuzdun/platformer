package main

import "core:math"
import la "core:math/linalg"


pressed_jump :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    return is.z_pressed && pls.can_press_jump || did_bunny_hop(pls, elapsed_time)
}


ground_jumped :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    cs := pls.contact_state
    return pressed_jump(pls, is, elapsed_time) && (cs.state == .ON_GROUND || (f32(elapsed_time) - cs.left_ground < COYOTE_TIME))
}


slope_jumped :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    cs := pls.contact_state
    return pressed_jump(pls, is, elapsed_time) && (cs.state == .ON_SLOPE || (f32(elapsed_time) - cs.left_slope < COYOTE_TIME))
}


wall_jumped :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    cs := pls.contact_state
    return pressed_jump(pls, is, elapsed_time) && (cs.state == .ON_WALL || (f32(elapsed_time) - cs.left_wall < COYOTE_TIME))
}


can_bunny_hop :: proc(pls: Player_State, elapsed_time: f32) -> bool {
    return  elapsed_time - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE
}


got_bunny_hop_input :: proc(pls: Player_State, elapsed_time: f32) -> bool {
    cs := pls.contact_state
    surface_touch_diff := math.abs(cs.touch_time - pls.jump_pressed_time)
    slide_end_diff := math.abs(pls.slide_state.slide_end_time - pls.jump_pressed_time)
    return (
        (cs.state != .IN_AIR && surface_touch_diff < BUNNY_WINDOW) ||
        (slide_end_diff < BUNNY_WINDOW && elapsed_time - pls.jump_pressed_time < BUNNY_WINDOW)
    )
}


did_bunny_hop :: proc(pls: Player_State, elapsed_time: f32) -> bool {
    return can_bunny_hop(pls, elapsed_time) && got_bunny_hop_input(pls, elapsed_time)
}


jumped :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    return ground_jumped(pls, is, elapsed_time) || slope_jumped(pls, is, elapsed_time) || wall_jumped(pls, is, elapsed_time) || did_bunny_hop(pls, elapsed_time)
}


on_surface :: proc(pls: Player_State) -> bool {
    state := pls.contact_state.state
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


