package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"


updated_trail_sample :: proc(pls: Player_State) -> [3][3]f32 {
    return {ring_buffer_at(pls.trail, -4), ring_buffer_at(pls.trail, -8), ring_buffer_at(pls.trail, -12)}
}


updated_trail_buffer :: proc(pls: Player_State) -> RingBuffer(TRAIL_SIZE, [3]f32) {
    new_trail := ring_buffer_copy(pls.trail)
    ring_buffer_push(&new_trail, [3]f32 {f32(pls.position.x), f32(pls.position.y), f32(pls.position.z)})
    return new_trail
}


updated_jump_pressed_time :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> f32 {
    if did_bunny_hop(pls, elapsed_time) {
        return 0
    }
    return (is.z_pressed && !pls.jump_held) ? elapsed_time : pls.jump_pressed_time
}


updated_spike_compression :: proc(pls: Player_State) -> f64 {
    if pls.contact_state.state == .ON_GROUND {
        return math.lerp(pls.spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } 
    return math.lerp(pls.spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
}


updated_crunch_time :: proc(pls: Player_State, elapsed_time: f32) -> f32 {
    did_bunny_hop := did_bunny_hop(pls, elapsed_time)
    return did_bunny_hop ? elapsed_time : pls.crunch_time 
}


updated_dash_hop_debounce_t :: proc(pls: Player_State, elapsed_time: f32) -> f32 {
    return did_bunny_hop(pls, elapsed_time) ? elapsed_time : pls.dash_hop_debounce_t 
}


updated_crunch_pt :: proc(pls: Player_State, elapsed_time: f32) -> [3]f32 {
    did_bunny_hop := did_bunny_hop(pls, elapsed_time)
    return did_bunny_hop ? pls.position : pls.crunch_pt
}


updated_screen_crunch_pt :: proc(pls: Player_State, cs: Camera_State, elapsed_time: f32) -> [2]f32 {
    new_crunch_pt := updated_crunch_pt(pls, elapsed_time)
    did_bunny_hop(pls, elapsed_time)
    if did_bunny_hop(pls, elapsed_time) {
        proj_mat :=  construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{new_crunch_pt.x, new_crunch_pt.y, new_crunch_pt.z, 1})
        return ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    } 
    return pls.screen_crunch_pt
}


updated_can_press_jump :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> bool {
    if jumped(pls, is, elapsed_time) {
        return false
    }
    return pls.can_press_jump || !is.z_pressed && on_surface(pls)
}


updated_tgt_particle_displacement :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> [3]f32 {
    new_tgt_particle_displacement := jumped(pls, is, elapsed_time) ? pls.velocity : pls.tgt_particle_displacement
    if pls.contact_state.state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, pls.velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    return new_tgt_particle_displacement
}


updated_particle_displacement :: proc(pls: Player_State) -> [3]f32 {
    return la.lerp(pls.particle_displacement, pls.tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
}


updated_dash_state :: proc(pls: Player_State, is: Input_State, collisions: map[int]struct{}, elapsed_time: f32) -> Dash_State {
    ds := pls.dash_state
    input_dir := input_dir(is)  
    if !on_surface(pls) && pls.slide_state.sliding == false && is.x_pressed && pls.dash_state.can_dash && pls.velocity != 0 && elapsed_time > pls.hurt_t + DAMAGE_LEN {
        ds.dashing = true 
        ds.dash_start_pos = pls.position
        dash_input := input_dir == 0 ? la.normalize0(pls.velocity.xz) : input_dir
        ds.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        ds.dash_end_pos = pls.position + DASH_DIST * ds.dash_dir
        ds.dash_time = f32(elapsed_time)
        ds.can_dash = false
    } else {
        if len(collisions) > 0 || on_surface(pls) || f32(elapsed_time) > ds.dash_time + DASH_LEN {
            ds.dashing = false 
        }
        if !pls.dash_state.can_dash {
            ds.can_dash = !ds.dashing && (pls.contact_state.state == .ON_GROUND || did_bunny_hop(pls, elapsed_time))
        } 
    }
    return ds
}


updated_slide_state :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> Slide_State {
    sls := pls.slide_state
    if on_surface(pls) && pls.slide_state.can_slide && is.x_pressed && pls.velocity != 0 {
        sls.sliding = true
        sls.can_slide = false
        sls.slide_time = elapsed_time
        sls.slide_start_pos = pls.position

        input_dir := input_dir(is)  
        surface_normal := la.normalize0(la.cross(pls.contact_state.ground_x, pls.contact_state.ground_z))
        slide_input := input_dir == 0 ? la.normalize0(pls.velocity) : {input_dir.x, 0, input_dir.y}
        sls.slide_dir = la.normalize(slide_input - la.dot(slide_input, surface_normal) * surface_normal)
    } else {
        if sls.sliding && (!on_surface(pls) || elapsed_time > sls.slide_time + SLIDE_LEN) {
            sls.sliding = false
            sls.slide_end_time = elapsed_time
        }
        if !sls.can_slide && !sls.sliding && sls.slide_end_time + SLIDE_COOLDOWN < elapsed_time {
            sls.can_slide = true
        }
    }
    return sls
}


updated_crunch_pts :: proc(pls: Player_State, cs: Camera_State, elapsed_time: f32) -> (new_crunch_pts: [dynamic][4]f32) {
    new_crunch_pts = make([dynamic][4]f32)
    for cpt in pls.crunch_pts {
        append(&new_crunch_pts, cpt)
    }
    idx := 0
    for _ in 0..<len(new_crunch_pts) {
        cpt := new_crunch_pts[idx]
        if elapsed_time - cpt[3] > 3000 {
            ordered_remove(&new_crunch_pts, idx) 
        } else {
            idx += 1
        }
    }
    if did_bunny_hop(pls, elapsed_time) {
        bg_crunch_pt := cs.position + la.normalize0(pls.position - cs.position) * 10000.0;
        append(&new_crunch_pts, [4]f32{bg_crunch_pt.x, bg_crunch_pt.y, bg_crunch_pt.z, updated_crunch_time(pls, elapsed_time)})
    }
    return
}

updated_hurt_t :: proc(pls: Player_State, collisions: map[int]struct{}, lgs: Level_Geometry_Soa, elapsed_time: f32) -> f32 {
    if pls.dash_state.dashing {
        return pls.hurt_t
    }
    for id in collisions {
        if .Hazardous in lgs[id].attributes {
            return elapsed_time
        }
    } 
    return pls.hurt_t
}


updated_broke_t :: proc(pls: Player_State, collisions: map[int]struct{}, lgs: Level_Geometry_Soa, elapsed_time: f32) -> f32 {
    if pls.dash_state.dashing {
        for id in collisions {
            if .Hazardous in lgs[id].attributes {
                return elapsed_time
            }
        } 
    }
    return pls.broke_t

}

