package main

import "constants"

Game_State :: struct {
    intensity: f32,
    score: int,
    time_remaining: f32,
    current_sector: int,
    last_checkpoint_t: f32,
    time_mult: f32
}

init_game_state :: proc(gs: ^Game_State) {
    using constants
    gs.time_remaining = TIME_LIMIT
    gs.last_checkpoint_t = -5000
    gs.time_mult = 1.0
}
