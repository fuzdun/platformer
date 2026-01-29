package main

import "core:fmt"

import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"


init_sdl :: proc() -> (controller: ^SDL.GameController, window: ^SDL.Window) {
    if SDL.Init({.VIDEO, .GAMECONTROLLER}) < 0 {
        fmt.println("SDL could not initialize")
    }
    SDL.GL_SetSwapInterval(1)

    if TTF.Init() == -1 {
        fmt.eprintln("failed to initialize TTF:", TTF.GetError())
    }

    for i in 0..<SDL.NumJoysticks() {
        if (SDL.IsGameController(i)) {
            controller = SDL.GameControllerOpen(i)
        }
    }

    if FORCE_EXTERNAL_MONITOR {
        external_display_rect: SDL.Rect
        SDL.GetDisplayBounds(1, &external_display_rect)

        window = SDL.CreateWindow(
            TITLE,
            external_display_rect.x,
            external_display_rect.y,
            external_display_rect.w,
            external_display_rect.h,
            {.OPENGL}
        )

    } else {
        window = SDL.CreateWindow(
            TITLE,
            0,
            0,
            WIDTH,
            HEIGHT,
            {.OPENGL}
        )
    }

    if window == nil {
        fmt.eprintln("Failed to create window")
    }

    if FULLSCREEN {
        SDL.SetWindowFullscreen(window, SDL.WINDOW_FULLSCREEN)
    }
    return
}

