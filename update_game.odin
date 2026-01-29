package main

import "constants"
import "core:math"
import la "core:math/linalg"


update_game :: proc(gs: ^Game_State, lgs: #soa[]Level_Geometry, pls: Player_State, triggers: Action_Triggers, collisions: Collision_Log, elapsed_time: f32, delta_time: f32) {
    using constants
    cts := pls.contact_state.state
    on_ground := cts == .ON_SLOPE || cts == .ON_GROUND

    new_score := gs.score
    new_score += int(gs.intensity * gs.intensity * 10.0)

    new_intensity := gs.intensity
    flat_speed := la.length(pls.velocity.xz)
    tgt_intensity := clamp((flat_speed - INTENSITY_MOD_MIN_SPD) / (INTENSITY_MOD_MAX_SPD - INTENSITY_MOD_MIN_SPD), 0, 1)

    if tgt_intensity > new_intensity {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.004))
    } else {
        new_intensity = math.lerp(new_intensity, tgt_intensity, f32(0.0010))
    }

    new_time_remaining := gs.time_remaining
    new_time_remaining = max(0, new_time_remaining - delta_time)

    new_sector := gs.current_sector
    new_checkpoint_t := gs.last_checkpoint_t
    if -pls.position.z > f32(CHUNK_DEPTH * (gs.current_sector + CHECKPOINT_SIZE)) {
        new_sector += CHECKPOINT_SIZE
        new_time_remaining += 3.0
        new_checkpoint_t = elapsed_time 
    }

    if triggers.restart  {
        new_sector = 0
        new_time_remaining = TIME_LIMIT
        new_score = 0
    }

    if new_time_remaining == 0 {
        new_intensity = 0
    }

    new_time_mult := gs.time_mult
    if pls.velocity.y < 0 || on_ground {
        new_time_mult = math.lerp(gs.time_mult, f32(1.0), f32(0.06))
    } else {
        new_time_mult = math.lerp(gs.time_mult, f32(1.0), f32(0.03))
    }

    if triggers.bunny_hop {
        new_time_mult = BUNNY_HOP_TIME_MULT - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_TIME_VARIANCE
    }

    for id in collisions {
        if .Bouncy in lgs[id].attributes {
            new_time_mult = 1.5
            break
        }
    }

    gs.score             = new_score
    gs.intensity         = new_intensity
    gs.time_remaining    = new_time_remaining
    gs.current_sector    = new_sector
    gs.last_checkpoint_t = new_checkpoint_t
    gs.time_mult         = new_time_mult
}
