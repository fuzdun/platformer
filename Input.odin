package main

import "core:fmt"
import "vendor:glfw"
import "base:runtime"
import SDL "vendor:sdl2"

u_pressed : bool = false
d_pressed : bool = false
r_pressed : bool = false
l_pressed : bool = false
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
                        l_pressed = true
                    case .RIGHT:
                        r_pressed = true
                    case .RSHIFT:
                        u_pressed = true
                    case .RCTRL:
                        d_pressed = true
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
                        l_pressed = false
                    case .RIGHT:
                        r_pressed = false
                    case .RSHIFT:
                        u_pressed = false
                    case .RCTRL:
                        d_pressed = false
                    case .SPACE:
                        spc_pressed = false
                }
            case .QUIT:
                quit_handler()
        }
    }
}
