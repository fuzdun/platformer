package main

game_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: ^Physics_State, rs: ^Render_State, bs: Buffer_State, cs: ^Camera_State, ts: ^Time_State, szs: ^Slide_Zone_State, elapsed_time: f32, delta_time: f32) {
    physics_map := build_physics_map(lgs^, phs.level_colliders, elapsed_time)
    input_attributes := get_input_attributes(is, elapsed_time, f32(delta_time))
    player_action_triggers := get_player_action_triggers(input_attributes, pls^, elapsed_time, delta_time)

    update_player(lgs, pls, phs, rs, cs, ts, szs, player_action_triggers, physics_map, elapsed_time, delta_time)
    update_particles(rs, bs, physics_map, player_action_triggers, pls.contact_state, pls.position, elapsed_time, delta_time)
    update_fx(rs, pls^, cs^, player_action_triggers, elapsed_time)
}
