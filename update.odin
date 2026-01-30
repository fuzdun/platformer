package main

gameplay_update :: proc(lgs: ^Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: ^Physics_State, rs: ^Render_State, ptcls: ^Particle_State, bs: Buffer_State, cs: ^Camera_State, szs: ^Slide_Zone_State, gs: ^Game_State, elapsed_time: f32, delta_time: f32) {
    physics_map := build_physics_map(lgs^, phs.level_colliders, elapsed_time)
    input_attributes := get_input_attributes(is, elapsed_time, f32(delta_time))
    player_action_triggers := get_player_action_triggers(input_attributes, pls^, szs^, elapsed_time, delta_time)

    // updated player state
    collisions, new_pls := update_player(
        lgs[:],
        pls^,
        gs^,
        player_action_triggers,
        physics_map,
        elapsed_time,
        delta_time
    )

    // mutate particle state (ptcls)
    update_particles(
        ptcls,
        bs,
        physics_map,
        player_action_triggers,
        new_pls,
        elapsed_time,
        delta_time
    )

    // mutate render state (rs)
    update_fx(
        rs,
        new_pls,
        cs^,
        player_action_triggers,
        elapsed_time
    )

    // updated level geometry state (lgs) and slide zone state (szs)
    new_lgs, new_szs_entities, new_szs_intersections := update_geometry(
        lgs,
        szs,
        new_pls,
        player_action_triggers,
        collisions,
        elapsed_time,
        delta_time
    )

    // mutate game state (gs)
    update_game(
        gs,
        lgs[:],
        new_pls,
        player_action_triggers,
        collisions,
        elapsed_time,
        delta_time
    )

    // mutate camera state (cs)
    update_camera(
        cs,
        new_pls,
        gs^,
        player_action_triggers
    )

    // mutate state
    pls^ = new_pls
    dynamic_soa_swap(lgs, new_lgs)
    dynamic_soa_swap(&szs.entities, new_szs_entities)
    set_swap(&szs.intersected, new_szs_intersections)
}

