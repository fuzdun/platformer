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
                        u_pressed = true
                    case .DOWN:
                        d_pressed = true
                    case .LEFT:
                        l_pressed = true
                    case .RIGHT:
                        r_pressed = true
                    case .RSHIFT:
                        f_pressed = true
                    case .RCTRL:
                        b_pressed = true
                }
            case .KEYUP:
                #partial switch event.key.keysym.sym {
                    case .UP:
                        u_pressed = false
                    case .DOWN:
                        d_pressed = false
                    case .LEFT:
                        l_pressed = false
                    case .RIGHT:
                        r_pressed = false
                    case .RSHIFT:
                        f_pressed = false
                    case .RCTRL:
                        b_pressed = false
                }
            case .QUIT:
                quit_handler()
        }
    }
}
