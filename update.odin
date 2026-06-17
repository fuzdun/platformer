package main
import hm "core:container/handle_map"

gameplay_update :: proc(
    lgs:   ^Level_Geometry_State,
    is:     Input_State,
    pls:   ^Player_State,
    phs:   ^Physics_State,
    rs:    ^Render_State,
    ptcls: ^Particle_State,
    bs:     Buffer_State,
    cs:    ^Camera_State,
    gs:    ^Game_State,
    elapsed_time: f32,
    delta_time: f32
) {

    physics_map := make([]Physics_Segment, PHYSICS_SEGMENT_COUNT, context.temp_allocator)
    for segment_idx in 0..<5 {
        physics_map[segment_idx] = make(Physics_Segment, context.temp_allocator)
    }
    lg_it := hm.iterator_make(lgs)
    for lg, lg_idx in hm.iterate(&lg_it) {
        broken := false
        #partial switch &v in lg.variant {
        case Shatter_Block:
            broken = !(v.shatter_data.crack_time == 0 || elapsed_time < v.shatter_data.crack_time + BREAK_DELAY) && v.shatter_data.smash_time == 0
        }
        if .Collider not_in lg.attributes || broken {
            continue
        }
        segment_idx: int = 0 //int(math.floor(lg.transform.position.z / PHYSICS_SEGMENT_SIZE)) 
        shape_data := phs.level_colliders[lg.shape]
        trans_mat := trans_to_mat4(lg.transform)
        coll: Collider
        coll.id = lg_idx
        coll.vertices = make([][3]f32, len(shape_data.vertices), context.temp_allocator)
        for vertex, vertex_i in shape_data.vertices {
            coll.vertices[vertex_i] = (trans_mat * [4]f32{vertex.x, vertex.y, vertex.z, 1.0}).xyz
        }
        coll.indices = make([]u16, len(shape_data.indices), context.temp_allocator)
        copy(coll.indices, shape_data.indices)
        coll.aabb = vertices_to_aabb(coll.vertices)
        append(&physics_map[segment_idx], coll)
    }

    input_attributes := get_input_attributes(is, elapsed_time, f32(delta_time))
    player_action_triggers := get_player_action_triggers(input_attributes, pls^, elapsed_time, delta_time)

    // mutate player state (pls)
    collisions := update_player(
        lgs,
        pls,
        gs^,
        input_attributes,
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
        pls^,
        elapsed_time,
        delta_time,
    )

    // mutate render state (rs)
    update_fx(
        rs,
        pls^,
        cs^,
        player_action_triggers,
        elapsed_time
    )

    // mutate level geometry state (lgs)
    update_geometry(
        lgs,
        pls^,
        player_action_triggers,
        collisions,
        elapsed_time,
        delta_time
    )

    // mutate game state (gs)
    update_game(
        gs,
        lgs,
        pls^,
        player_action_triggers,
        collisions,
        elapsed_time,
        delta_time
    )

    // mutate camera state (cs)
    update_camera(
        cs,
        pls^,
        gs^,
        player_action_triggers
    )
}

