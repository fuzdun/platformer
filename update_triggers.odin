package main

import "core:math"
import "core:fmt"

Action_Triggers :: struct {
    jump_pressed_time: f32,
    jump: bool,
    small_hop: bool,
    bunny_hop: bool,
    restart: bool,
    checkpoint: bool,
}

get_player_action_triggers :: proc(
    input: Input_Attributes,
    pls: Player_State,
    elapsed_time: f32,
    delta_time: f32
) -> (out: Action_Triggers) {
    out.jump_pressed_time = pls.jump_pressed_time
    if input.jump_pressed && !pls.jump_held {
        out.jump_pressed_time = elapsed_time
    }
    jump_input := input.jump_pressed || abs(pls.touch_time - out.jump_pressed_time) < BUNNY_WINDOW
    out.jump = jump_input && pls.jump_enabled
    beat_window := math.abs(math.round(current_beat_progress) - current_beat_progress)
    out.bunny_hop = out.jump && beat_window < TEST_PERFECT_WINDOW
    out.small_hop = out.jump && !out.bunny_hop && beat_window < TEST_OK_WINDOW
    out.restart = input.restart_pressed
    out.checkpoint = pls.position.y < -100
    return
}
