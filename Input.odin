package main

import "core:fmt"
import "vendor:glfw"
import "base:runtime"
import SDL "vendor:sdl2"

a_pressed : bool = false
s_pressed : bool = false
d_pressed : bool = false
w_pressed : bool = false
q_pressed : bool = false
e_pressed : bool = false
up_pressed : bool = false
down_pressed : bool = false
right_pressed : bool = false
left_pressed : bool = false
f_pressed : bool = false
b_pressed : bool = false
spc_pressed : bool = false

process_input :: proc (quit_handler: proc()) 
{
    event : SDL.Event
    for SDL.PollEvent(&event) {
        #partial switch event.type {
            case .KEYDOWN:
                #partial switch event.key.keysym.sym {
                    case .ESCAPE:
                        quit_handler()
                    case .UP:
                        f_pressed = true
                    case .DOWN:
                        b_pressed = true
                    case .LEFT:
                        left_pressed = true
                    case .RIGHT:
                        right_pressed = true
                    case .a:
                        a_pressed = true
                    case .s:
                        s_pressed = true
                    case .d:
                        d_pressed = true
                    case .w:
                        w_pressed = true
                    case .q:
                        q_pressed = true
                    case .e:
                        e_pressed = true
                    case .RSHIFT:
                        up_pressed = true
                    case .RCTRL:
                        down_pressed = true
                    case .SPACE:
                        spc_pressed = true
                }
            case .KEYUP:
                #partial switch event.key.keysym.sym {
                    case .UP:
                        f_pressed = false
                    case .DOWN:
                        b_pressed = false
                    case .LEFT:
                        left_pressed = false
                    case .RIGHT:
                        right_pressed = false
                    case .RSHIFT:
                        up_pressed = false
                    case .RCTRL:
                        down_pressed = false
                    case .a:
                        a_pressed = false
                    case .s:
                        s_pressed = false
                    case .d:
                        d_pressed = false
                    case .w:
                        w_pressed = false
                    case .q:
                        q_pressed = false
                    case .e:
                        e_pressed = false
                    case .SPACE:
                        spc_pressed = false
                }
            case .QUIT:
                quit_handler()
        }
    }
}
