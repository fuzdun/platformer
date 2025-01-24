package main
import "core:fmt"

game_update :: proc(gs: ^GameState, elapsed_time: f64, delta_time: f64) {
    move_player(elapsed_time, delta_time)
    move_camera(elapsed_time, delta_time)
    trans_apply_velocities(&gs.ecs, delta_time)
}

