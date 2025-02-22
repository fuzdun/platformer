package main

import "core:fmt"
import "vendor:glfw"
import "base:runtime"
import SDL "vendor:sdl2"

Input_State :: struct {
    a_pressed: bool,
    d_pressed: bool,
    s_pressed: bool,
    w_pressed: bool,
    c_pressed: bool,
    left_pressed: bool,
    right_pressed: bool,
    up_pressed : bool, 
    down_pressed: bool,
    pg_up_pressed: bool,
    pg_down_pressed: bool,
    tab_pressed: bool,
    e_pressed: bool,
    r_pressed: bool,
    ent_pressed: bool,
    spc_pressed: bool,
    hor_axis: f32,
    vert_axis: f32
}

process_input :: proc (is: ^Input_State, quit_handler: proc()) 
{
    event : SDL.Event
    for SDL.PollEvent(&event) {
        #partial switch event.type {
        case .CONTROLLERAXISMOTION:
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
        case .CONTROLLERBUTTONDOWN:
            switch event.cbutton.button {
            case 1:
                is.spc_pressed = true
            }
        case .CONTROLLERBUTTONUP:
            switch event.cbutton.button {
            case 1:
                is.spc_pressed = false
            }
        case .KEYDOWN:
            #partial switch event.key.keysym.sym {
            case .ESCAPE:
                quit_handler()
            case .a:
                is.a_pressed = true
            case .s:
                is.s_pressed = true
            case .d:
                is.d_pressed = true
            case .w:
                is.w_pressed = true
            case .LEFT:
                is.left_pressed = true
            case .RIGHT:
                is.right_pressed = true
            case .UP:
                is.up_pressed = true
            case .DOWN:
                is.down_pressed = true
            case .PAGEUP:
                is.pg_up_pressed = true
            case .PAGEDOWN:
                is.pg_down_pressed = true
            case .TAB:
                is.tab_pressed = true
            case .R:
                is.r_pressed = true
            case .E:
                is.e_pressed = true
            case .RETURN:
                is.ent_pressed = true
            case .c:
                is.c_pressed = true
            case .SPACE:
                is.spc_pressed = true
            }
        case .KEYUP:
            #partial switch event.key.keysym.sym {
            case .a:
                is.a_pressed = false
            case .s:
                is.s_pressed = false
            case .d:
                is.d_pressed = false
            case .w:
                is.w_pressed = false
            case .LEFT:
                is.left_pressed = false
            case .RIGHT:
                is.right_pressed = false
            case .UP:
                is.up_pressed = false
            case .DOWN:
                is.down_pressed = false
            case .PAGEUP:
                is.pg_up_pressed = false
            case .PAGEDOWN:
                is.pg_down_pressed = false
            case .TAB:
                is.tab_pressed = false
            case .R:
                is.r_pressed = false
            case .E:
                is.e_pressed = false
            case .RETURN:
                is.ent_pressed = false
            case .c:
                is.c_pressed = false
            case .SPACE:
                is.spc_pressed = false
            }
        case .QUIT:
            quit_handler()
        }
    }
}
