package main

import "core:fmt"
import "constants"
import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"


update_fx :: proc(rs: ^Render_State, pls: Player_State, cs: Camera_State, triggers: Action_Triggers, elapsed_time: f32) {
    using constants
    cts := pls.contact_state

    // player vertex displacement
    // -------------------------------------------
    new_tgt_player_vertex_displacement := rs.tgt_player_vertex_displacement
    if triggers.jump {
        new_tgt_player_vertex_displacement = pls.velocity
    }
    if cts.state != .ON_GROUND {
        new_tgt_player_vertex_displacement = la.lerp(new_tgt_player_vertex_displacement, pls.velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_player_vertex_displacement = la.lerp(new_tgt_player_vertex_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    new_player_vertex_displacement := la.lerp(rs.player_vertex_displacment, new_tgt_player_vertex_displacement, PARTICLE_DISPLACEMENT_LERP)

    // player spike compression
    // -------------------------------------------
    new_player_spike_compression := rs.player_spike_compression
    if cts.state == .ON_GROUND {
        new_player_spike_compression = math.lerp(rs.player_spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } else {
        new_player_spike_compression = math.lerp(rs.player_spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    }

    // crunch_time
    // -------------------------------------------
    new_crunch_time := triggers.bunny_hop ? elapsed_time : rs.crunch_time

    // crunch pt
    // -------------------------------------------
    new_crunch_pt := rs.crunch_pt
    if triggers.bunny_hop {
        new_crunch_pt = pls.position
    }

    // screen ripple
    // -------------------------------------------
    new_screen_ripple_pt := rs.screen_ripple_pt
    if triggers.bunny_hop {
        proj_mat := construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{
            new_crunch_pt.x,
            new_crunch_pt.y,
            new_crunch_pt.z,
            1
        })
        new_screen_ripple_pt = ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    }

    // screen splashes
    // --------------------------------------------
    new_screen_splashes := make([dynamic][4]f32, len(rs.screen_splashes))
    copy(new_screen_splashes[:], rs.screen_splashes[:])
    splash_idx := 0
    for _ in 0 ..<len(new_screen_splashes) {
        splash := new_screen_splashes[splash_idx]
        if elapsed_time - splash[3] > 10000 {
            ordered_remove(&new_screen_splashes, splash_idx)
        } else {
            splash_idx += 1
        }
    }
    if triggers.bunny_hop {
        new_splash := cs.position + la.normalize0(pls.position - cs.position) * 10000.0;
        append(&new_screen_splashes, [4]f32{
            new_splash.x,
            new_splash.y,
            new_splash.z,
            new_crunch_time
        })
    }
    if len(rs.screen_splashes) > 5 {
        ordered_remove(&rs.screen_splashes, 0);
    }

    // trail
    // --------------------------------------------
    new_player_trail_sample := [3]glm.vec3{
        ring_buffer_at(rs.player_trail, -4),
        ring_buffer_at(rs.player_trail, -8),
        ring_buffer_at(rs.player_trail, -12),
    }

    new_player_trail := ring_buffer_copy(rs.player_trail)
    ring_buffer_push(&new_player_trail, pls.position)


    // #####################################################
    // MUTATE FX STATE 
    // #####################################################

    // prev frame values
    // -------------------------------------------
    rs.prev_player_trail_sample = rs.player_trail_sample

    // overwrite state properties
    //--------------------------------------------
    ring_buffer_swap(&rs.player_trail,      new_player_trail)
    dynamic_array_swap(&rs.screen_splashes, new_screen_splashes)
    rs.crunch_time                        = new_crunch_time
    rs.crunch_pt                          = new_crunch_pt
    rs.tgt_player_vertex_displacement     = new_tgt_player_vertex_displacement
    rs.player_vertex_displacment          = new_player_vertex_displacement
    rs.player_spike_compression           = new_player_spike_compression
    rs.screen_ripple_pt                   = new_screen_ripple_pt
    rs.player_trail_sample                = new_player_trail_sample
}
