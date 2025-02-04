package main
import "core:fmt"

game_update :: proc(gs: ^Game_State, ps: ^Physics_State, elapsed_time: f64, delta_time: f64) {
    //fmt.println("============update===========")
    move_player(gs.input_state, &gs.player_state, elapsed_time, delta_time)
    move_camera(gs.player_state, &gs.camera_state, elapsed_time, delta_time)
    apply_velocities(gs.level_geometry, delta_time)
    broad_phase_collisions(gs, ps)
    narrow_phase_collisions(gs, ps)
}

