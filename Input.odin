package main

import "vendor:glfw"
import "base:runtime"

u_pressed : bool = false
d_pressed : bool = false
r_pressed : bool = false
l_pressed : bool = false
f_pressed : bool = false
b_pressed : bool = false

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32)
{
    context = runtime.default_context()
    using glfw
    if key == KEY_UP && action == PRESS {
        u_pressed = true
    }
    if key == KEY_UP && action == RELEASE {
        u_pressed = false
    }
    if key == KEY_DOWN && action == PRESS {
        d_pressed = true
    }
    if key == KEY_DOWN && action == RELEASE {
        d_pressed = false
    }
    if key == KEY_RIGHT && action == PRESS {
        r_pressed = true
    }
    if key == KEY_RIGHT && action == RELEASE {
        r_pressed = false
    }
    if key == KEY_LEFT && action == PRESS {
        l_pressed = true
    }
    if key == KEY_LEFT && action == RELEASE {
        l_pressed = false
    }
    if key == KEY_RIGHT_SHIFT && action == PRESS {
        f_pressed = true
    }
    if key == KEY_RIGHT_SHIFT && action == RELEASE {
        f_pressed = false
    }
    if key == KEY_RIGHT_CONTROL && action == PRESS {
        b_pressed = true
    }
    if key == KEY_RIGHT_CONTROL && action == RELEASE {
        b_pressed = false
    }
}
