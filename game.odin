package main
import "core:fmt"
import st "state"

game_update :: proc(gs: ^st.Game_State, lrs: st.Level_Resources, pls: ^st.Player_State, ps: ^st.Physics_State, rs: ^st.Render_State, elapsed_time: f64, delta_time: f32) {
    //fmt.println("============update===========")
    if EDIT {
        get_selected_geometry_dists(&gs.editor_state, ps^, gs.level_geometry)
        editor_move_camera(&gs.level_geometry, &gs.editor_state, &gs.camera_state, delta_time)
        editor_move_object(gs, lrs, &gs.editor_state, gs.input_state, ps, rs, delta_time)
        editor_save_changes(&gs.level_geometry, gs.input_state, &gs.editor_state)
    } else {
        update_player_velocity(gs, pls, elapsed_time, delta_time)
        move_player(gs, pls, ps, f32(elapsed_time), delta_time)
        move_camera(pls^, &gs.camera_state, elapsed_time, delta_time)
    }
}

