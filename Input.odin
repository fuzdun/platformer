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
    spc_pressed: bool,
}

process_input :: proc (is: ^Input_State, quit_handler: proc()) 
{
    event : SDL.Event
    for SDL.PollEvent(&event) {
        #partial switch event.type {
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
