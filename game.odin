package main
import "core:fmt"

game_update :: proc(gs: ^Game_State, ps: ^Physics_State, rs: ^Render_State, elapsed_time: f64, delta_time: f32) {
    //fmt.println("============update===========")
    if EDIT {
        get_selected_geometry_dists(&gs.editor_state, ps^, gs.level_geometry)
        editor_move_camera(&gs.level_geometry, &gs.editor_state, &gs.camera_state, delta_time)
        editor_move_object(gs, &gs.editor_state, gs.input_state, ps, rs, delta_time)
        editor_save_changes(&gs.level_geometry, gs.input_state, &gs.editor_state)
    } else {
        update_player_velocity(gs, elapsed_time, delta_time)
        move_player(gs, ps, f32(elapsed_time), delta_time)
        move_camera(gs.player_state, &gs.camera_state, elapsed_time, delta_time)
    }
}

