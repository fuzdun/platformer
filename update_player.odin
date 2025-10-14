package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"


updated_trail_sample :: proc(trail: RingBuffer(TRAIL_SIZE, [3]f32)) -> [3][3]f32 {
    return {ring_buffer_at(trail, -4), ring_buffer_at(trail, -8), ring_buffer_at(trail, -12)}
}


updated_trail_buffer :: proc(trail: RingBuffer(TRAIL_SIZE, [3]f32), position: [3]f32) -> RingBuffer(TRAIL_SIZE, [3]f32) {
    new_trail := ring_buffer_copy(trail)
    ring_buffer_push(&new_trail, [3]f32 {f32(position.x), f32(position.y), f32(position.z)})
    return new_trail
}


updated_jump_pressed_time :: proc(did_bunny_hop: bool, z_pressed: bool, jump_held: bool, jump_pressed_time: f32, elapsed_time: f32) -> f32 {
    if did_bunny_hop {
        return 0
    }
    return (z_pressed && !jump_held) ? elapsed_time : jump_pressed_time
}

updated_wall_detach_held_t :: proc(wall_detach_held_t: f32, state: Player_States, is: Input_State, contact_ray: [3]f32, delta_time: f32) -> f32 {
    wall_detach_held_t := wall_detach_held_t
    contact_ray := la.normalize0(contact_ray)
    if state == .ON_WALL {
        input_dir := input_dir(is)  
        vec3_input_dir := [3]f32{input_dir.x, 0, input_dir.y}
        if la.dot(vec3_input_dir, contact_ray) >= 0 {
            wall_detach_held_t = 0
        } else {
            wall_detach_held_t += delta_time * 1000.0
            //fmt.println(wall_detach_held_t)
        }
    } else {
        wall_detach_held_t = 0
    }
    return wall_detach_held_t
} 


updated_spike_compression :: proc(spike_compression: f32, state: Player_States) -> f32 {
    if state == .ON_GROUND {
        return math.lerp(spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } 
    return math.lerp(spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
}


updated_crunch_time :: proc(crunch_time: f32, did_bunny_hop: bool, elapsed_time: f32) -> f32 {
    return did_bunny_hop ? elapsed_time : crunch_time 
}


updated_dash_hop_debounce_t :: proc(dash_hop_debounce_t: f32, did_bunny_hop: bool, elapsed_time: f32) -> f32 {
    return did_bunny_hop ? elapsed_time : dash_hop_debounce_t 
}


updated_crunch_pt :: proc(crunch_pt: [3]f32, position: [3]f32, did_bunny_hop: bool, elapsed_time: f32) -> [3]f32 {
    did_bunny_hop := did_bunny_hop
    return did_bunny_hop ? position : crunch_pt
}


updated_screen_crunch_pt :: proc(screen_crunch_pt: [2]f32, position: [3]f32, crunch_pt: [3]f32, did_bunny_hop: bool, cs: Camera_State, elapsed_time: f32) -> [2]f32 {
    new_crunch_pt := updated_crunch_pt(crunch_pt, position, did_bunny_hop, elapsed_time)
    if did_bunny_hop {
        proj_mat :=  construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{new_crunch_pt.x, new_crunch_pt.y, new_crunch_pt.z, 1})
        return ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    } 
    return screen_crunch_pt
}


updated_can_press_jump :: proc(can_press_jump: bool, state: Player_States, jumped: bool, z_pressed: bool, elapsed_time: f32) -> bool {
    if jumped {
        return false
    }
    return can_press_jump || !z_pressed && on_surface(state)
}


updated_tgt_particle_displacement :: proc(tgt_particle_displacement: [3]f32, state: Player_States, velocity: [3]f32, jumped: bool,  elapsed_time: f32) -> [3]f32 {
    new_tgt_particle_displacement := jumped ? velocity : tgt_particle_displacement
    if state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    return new_tgt_particle_displacement
}


updated_particle_displacement :: proc(particle_displacement: [3]f32, tgt_particle_displacement: [3]f32) -> [3]f32 {
    return la.lerp(particle_displacement, tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
}


updated_dash_state :: proc(ds: Dash_State, state: Player_States, sliding: bool, hurt_t: f32, position: [3]f32, velocity: [3]f32, is: Input_State, did_bunny_hop: bool, collisions: map[int]struct{}, elapsed_time: f32, delta_time: f32) -> Dash_State {
    ds := ds
    if ds.dashing {
        ds.dash_total += delta_time * 1000
    }
    if !on_surface(state) && sliding == false && is.x_pressed && ds.can_dash && velocity != 0 && elapsed_time > hurt_t + DAMAGE_LEN {
        input_dir := input_dir(is)  
        ds.dashing = true 
        ds.dash_start_pos = position
        dash_input := input_dir == 0 ? la.normalize0(velocity.xz) : input_dir
        ds.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        ds.dash_end_pos = position + DASH_DIST * ds.dash_dir
        ds.dash_time = f32(elapsed_time)
        ds.dash_total = 0 
        ds.can_dash = false
    } else {
        // if len(collisions) > 0 || on_surface(state) || f32(elapsed_time) > ds.dash_time + DASH_LEN {
        if (elapsed_time < hurt_t + DAMAGE_LEN) || on_surface(state) || ds.dash_total > DASH_LEN {
            ds.dashing = false 
            ds.dash_total = 0
        }
        if !ds.can_dash {
            ds.can_dash = !ds.dashing && (state == .ON_GROUND || state == .ON_SLOPE || did_bunny_hop)
        } 
    }
    return ds
}

updated_slide_state :: proc(sls: Slide_State, is: Input_State, state: Player_States, position: [3]f32, velocity: [3]f32, ground_x: [3]f32, ground_z: [3]f32, collisions: map[int]struct{}, lgs: #soa[]Level_Geometry, slide_zone_intersections: map[int]struct{}, elapsed_time: f32, delta_time: f32) -> Slide_State {
    new_sls := sls
    if sls.sliding {
        new_sls.slide_total += delta_time * 1000.0
    }
    if on_surface(state) && sls.can_slide && is.x_pressed && velocity != 0 {
        new_sls.sliding = true
        new_sls.can_slide = false
        new_sls.slide_time = elapsed_time
        new_sls.mid_slide_time = elapsed_time
        new_sls.slide_start_pos = position
        new_sls.slide_total = 0

        input_dir := input_dir(is)  
        surface_normal := la.normalize0(la.cross(ground_x, ground_z))
        slide_input := input_dir == 0 ? la.normalize0(velocity) : {input_dir.x, 0, input_dir.y}
        new_sls.slide_dir = la.normalize(slide_input - la.dot(slide_input, surface_normal) * surface_normal)
    } else {
        if sls.sliding && len(slide_zone_intersections) > 0{
            new_sls.mid_slide_time = elapsed_time
        }
        // if sls.sliding && (!on_surface(state) || elapsed_time > sls.mid_slide_time + SLIDE_LEN) {
        slide_off := sls.mid_slide_time - sls.slide_time
        if sls.sliding && (!on_surface(state) || (new_sls.slide_total - slide_off) > SLIDE_LEN) {
            new_sls.sliding = false
            new_sls.slide_end_time = elapsed_time
            new_sls.slide_total = 0
        }
        if !sls.can_slide && !sls.sliding && sls.slide_end_time + SLIDE_COOLDOWN < elapsed_time {
            new_sls.can_slide = true
        }
    }
    return new_sls
}


updated_crunch_pts :: proc(crunch_pts: [][4]f32, crunch_time: f32, did_bunny_hop: bool, cs: Camera_State, position: [3]f32, elapsed_time: f32) -> (new_crunch_pts: [dynamic][4]f32) {
    new_crunch_pts = make([dynamic][4]f32)
    for cpt in crunch_pts {
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
    if did_bunny_hop {
        bg_crunch_pt := cs.position + la.normalize0(position - cs.position) * 10000.0;
        append(&new_crunch_pts, [4]f32{bg_crunch_pt.x, bg_crunch_pt.y, bg_crunch_pt.z,
            updated_crunch_time(crunch_time, did_bunny_hop, elapsed_time)})
    }
    return
}

updated_hurt_t :: proc(hurt_t: f32, dashing: bool, sliding: bool, collisions: map[int]struct{}, lgs: #soa[]Level_Geometry, elapsed_time: f32) -> f32 {
    if !dashing {
        for id in collisions {
            attr := lgs[id].attributes
            satisfied := (dashing && .Dash_Breakable in attr) || (sliding && .Slide_Zone in attr)
            if .Hazardous in attr && !satisfied{
                return elapsed_time
            }
        } 
    }
    return hurt_t
}


updated_broke_t :: proc(broke_t: f32, dashing: bool, collisions: map[int]struct{}, lgs: #soa[]Level_Geometry, elapsed_time: f32) -> f32 {
    if dashing {
        for id in collisions {
            if .Hazardous in lgs[id].attributes {
                return elapsed_time
            }
        } 
    }
    return broke_t

}

