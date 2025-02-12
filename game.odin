package main
import "core:fmt"

game_update :: proc(gs: ^Game_State, ps: ^Physics_State, elapsed_time: f64, delta_time: f32) {
    //fmt.println("============update===========")
    apply_velocities(gs.level_geometry, delta_time)
    update_player_velocity(gs.input_state, &gs.player_state, elapsed_time, delta_time)
    //get_collisions(gs, ps)
    move_player(gs, ps, f32(elapsed_time), delta_time)
    move_camera(gs.player_state, &gs.camera_state, elapsed_time, delta_time)
    //narrow_phase_collisions(gs, ps)
}

