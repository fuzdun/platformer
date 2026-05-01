package main

import SDL "vendor:sdl3"
import imsdl "shared:odin-imgui/imgui_impl_sdl3"

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
    alt_pressed: bool,
    lctrl_pressed: bool,
    lshift_pressed: bool,
    f12_pressed: bool,
    hor_axis: f32,
    vert_axis: f32
}

process_input :: proc (is: ^Input_State, quit_handler: proc()) {
    event : SDL.Event
    for SDL.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            quit_handler()
        }
        when ODIN_OS != .Windows {
            if EDIT {
                imsdl.process_event(&event)
            }
        }
        #partial switch event.type {
        case .GAMEPAD_AXIS_MOTION:
            if event.jaxis.axis == 0 {
                if (event.jaxis.value < -10000 || event.jaxis.value > 10000) {
                    is.hor_axis = f32(event.jaxis.value) / 32767.0
                } else {
                    is.hor_axis = 0
                }
            }
            if event.jaxis.axis == 1 {
                if (event.jaxis.value < -10000 || event.jaxis.value > 10000) {
                    is.vert_axis = -f32(event.jaxis.value) / 32767.0
                } else {
                    is.vert_axis = 0
                }
            }
        case .GAMEPAD_BUTTON_DOWN:
            switch event.gbutton.button {
            case u8(SDL.GamepadButton.SOUTH):
                is.z_pressed = true
            case u8(SDL.GamepadButton.EAST):
                is.r_pressed = true
            case u8(SDL.GamepadButton.WEST):
                is.x_pressed = true
            case u8(SDL.GamepadButton.RIGHT_SHOULDER):
                is.c_pressed = true
            }
        case .GAMEPAD_BUTTON_UP:
            switch event.gbutton.button {
            case u8(SDL.GamepadButton.SOUTH):
                is.z_pressed = false
            case u8(SDL.GamepadButton.EAST):
                is.r_pressed = false
            case u8(SDL.GamepadButton.WEST):
                is.x_pressed = false
            case u8(SDL.GamepadButton.RIGHT_SHOULDER):
                is.c_pressed = false
            }
        case .KEY_DOWN:
            switch event.key.key {
            case SDL.K_ESCAPE:
                quit_handler()
            case SDL.K_A:
                is.a_pressed = true
            case SDL.K_S:
                is.s_pressed = true
            case SDL.K_D:
                is.d_pressed = true
            case SDL.K_W:
                is.w_pressed = true
            case SDL.K_Q:
                is.q_pressed = true
            case SDL.K_Z:
                is.z_pressed = true
            case SDL.K_X:
                is.x_pressed = true
            case SDL.K_COMMA:
                is.lt_pressed = true
            case SDL.K_PERIOD:
                is.gt_pressed = true
            case SDL.K_LEFT:
                is.left_pressed = true
            case SDL.K_RIGHT:
                is.right_pressed = true
            case SDL.K_UP:
                is.up_pressed = true
            case SDL.K_DOWN:
                is.down_pressed = true
            case SDL.K_PAGEUP:
                is.pg_up_pressed = true
            case SDL.K_PAGEDOWN:
                is.pg_down_pressed = true
            case SDL.K_TAB:
                is.tab_pressed = true
            case SDL.K_BACKSPACE:
                is.bck_pressed = true
            case SDL.K_R:
                is.r_pressed = true
            case SDL.K_E:
                is.e_pressed = true
            case SDL.K_RETURN:
                is.ent_pressed = true
            case SDL.K_C:
                is.c_pressed = true
            case SDL.K_SPACE:
                is.spc_pressed = true
            case SDL.K_LALT:
                is.alt_pressed = true
            case SDL.K_LCTRL:
                is.lctrl_pressed = true
            case SDL.K_LSHIFT:
                is.lshift_pressed = true
            case SDL.K_F12:
                is.f12_pressed = true
            }
        case .KEY_UP:
            switch event.key.key {
            case SDL.K_A:
                is.a_pressed = false
            case SDL.K_S:
                is.s_pressed = false
            case SDL.K_D:
                is.d_pressed = false
            case SDL.K_W:
                is.w_pressed = false
            case SDL.K_Z:
                is.z_pressed = false
            case SDL.K_X:
                is.x_pressed = false
            case SDL.K_Q:
                is.q_pressed = false
            case SDL.K_COMMA:
                is.lt_pressed = false
            case SDL.K_PERIOD:
                is.gt_pressed = false
            case SDL.K_LEFT:
                is.left_pressed = false
            case SDL.K_RIGHT:
                is.right_pressed = false
            case SDL.K_UP:
                is.up_pressed = false
            case SDL.K_DOWN:
                is.down_pressed = false
            case SDL.K_PAGEUP:
                is.pg_up_pressed = false
            case SDL.K_PAGEDOWN:
                is.pg_down_pressed = false
            case SDL.K_TAB:
                is.tab_pressed = false
            case SDL.K_BACKSPACE:
                is.bck_pressed = false
            case SDL.K_R:
                is.r_pressed = false
            case SDL.K_E:
                is.e_pressed = false
            case SDL.K_RETURN:
                is.ent_pressed = false
            case SDL.K_C:
                is.c_pressed = false
            case SDL.K_SPACE:
                is.spc_pressed = false
            case SDL.K_LALT:
                is.alt_pressed = false
            case SDL.K_LCTRL:
                is.lctrl_pressed = false
            case SDL.K_LSHIFT:
                is.lshift_pressed = false
            case SDL.K_F12:
                is.f12_pressed = false
            }
        }
    }
}

