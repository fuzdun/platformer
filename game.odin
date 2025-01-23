package main
import "core:fmt"

game_update :: proc(gs: ^GameState, delta_time: f64) {
    move_camera(delta_time)
    trans_apply_velocities(&gs.ecs, delta_time)
}

