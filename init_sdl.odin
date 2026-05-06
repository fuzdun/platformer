package main

import "core:fmt"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"


init_sdl :: proc() -> (controller: ^SDL.Gamepad, window: ^SDL.Window, audio_device: SDL.AudioDeviceID) {
    if !SDL.Init({.VIDEO, .GAMEPAD, .AUDIO}) {
        fmt.println("SDL could not initialize")
    }
    SDL.GL_SetSwapInterval(1)

    if !TTF.Init() {
        fmt.eprintln("failed to initialize TTF")
    }

    num_joysticks: i32
    joysticks := SDL.GetJoysticks(&num_joysticks)

    for i in 0..<num_joysticks {
        if SDL.IsGamepad(SDL.JoystickID(i)) {
            controller = SDL.OpenGamepad(SDL.JoystickID(i))
        }
    }

    if FORCE_EXTERNAL_MONITOR {
        external_display_rect: SDL.Rect
        SDL.GetDisplayBounds(1, &external_display_rect)

        window = SDL.CreateWindow(
            TITLE,
            external_display_rect.w,
            external_display_rect.h,
            {.OPENGL}
        )

    } else {
        window = SDL.CreateWindow(
            TITLE,
            WIDTH,
            HEIGHT,
            {.OPENGL}
        )
    }

    if window == nil {
        fmt.eprintln("Failed to create window")
    }

    if FULLSCREEN {
        SDL.SetWindowFullscreen(window, true)
    }

    // audio_device = SDL.OpenAudioDevice(SDL.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil) 

    return
}

