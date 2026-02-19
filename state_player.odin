package main

import "base:runtime"
import "core:math"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"

SPIN_TRAILS_VERTICES: [4]Quad_Vertex : {} 

Contact_State :: struct {
    state: Player_States,
    touch_time: f32,
    left_ground: f32,
    left_slope: f32,
    left_wall: f32,
    contact_ray: [3]f32,
    last_touched: int
}

Dash_State :: struct {
    dash_start_pos: [3]f32,
    dash_dir: [3]f32,
    dash_time: f32,
    dash_spd: f32
}

Slide_State :: struct {
    slide_time: f32,
    mid_slide_time: f32,
    slide_dir: [3]f32,
    slide_start_pos: [3]f32,
    slide_end_time: f32,
}

Spin_State :: struct {
    //spinning: bool,
    spin_time: f32,
    spin_dir: [2]f32,
    spin_amt: f32,
}

Player_Mode :: enum {
    Normal,
    Dashing,
    Sliding,
}

Player_State :: struct {
    mode: Player_Mode,
    contact_state: Contact_State,
    dash_state: Dash_State,
    slide_state: Slide_State,
    spin_state: Spin_State, 

    hops_remaining: int,
    hops_recharge: f32,

    hurt_t: f32,
    broke_t: f32,

    position: [3]f32,
    velocity: [3]f32,

    ground_x: [3]f32,
    ground_z: [3]f32,

    jump_enabled: bool,
    dash_enabled: bool,
    slide_enabled: bool,

    jump_held: bool,
    jump_pressed_time: f32,
    last_hop: f32,
    wall_detach_held_t: f32,

    prev_position: [3]f32,
}

init_player_state :: proc(pls: ^Player_State, perm_alloc: runtime.Allocator) {
    pls.contact_state.state = .IN_AIR
    pls.position = INIT_PLAYER_POS
    pls.dash_enabled = true
    pls.slide_enabled = true
    pls.slide_state.slide_end_time = -SLIDE_COOLDOWN
    pls.jump_enabled = false
    pls.ground_x = {1, 0, 0}
    pls.ground_z = {0, 0, -1}
    pls.contact_state.touch_time = -1000.0
    pls.hurt_t = -5000.0
    pls.broke_t = -5000.0
}

free_player_state :: proc(ps: ^Player_State) {}

Player_States :: enum {
    ON_GROUND,
    ON_WALL,
    ON_SLOPE,
    IN_AIR,
    DASHING,
}

interpolated_player_pos :: proc(ps: Player_State, t: f32) -> [3]f32 {
    return math.lerp(ps.prev_position, ps.position, t) 
}

interpolated_player_matrix :: proc(ps: Player_State, t: f32) -> matrix[4, 4]f32 {
    i_pos := math.lerp(ps.prev_position, ps.position, t) 
    rot := I_MAT
    offset := glm.mat4Translate({f32(i_pos.x), f32(i_pos.y), f32(i_pos.z)})
    return rot * offset
}

animate_player_vertices_sliding :: proc(vertices: []Vertex, contact_ray: [3]f32, slide_total: f32, slide_off: f32, time: f32) {
    up := la.normalize(contact_ray)
    spin_mat := la.matrix4_rotate_f32(f32(time) / 150, up)
    slide_t := slide_total
    end_slide_t := (slide_total - slide_off) - (SLIDE_LEN - SLIDE_ANIM_EASE_LEN)
    expansion_t := clamp(slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0) - clamp(end_slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0)
    for &v, idx in vertices {
        vertical_fact := la.dot(up, v.pos)
        v.pos -= up * vertical_fact * easeout_cubic(expansion_t) * abs(vertical_fact) * 1.2
        if v.uv.x == 1.0 {
            v.pos *= (1.0 + (expansion_t) * 4.0)
        }
        v.pos = la.matrix_mul_vector(spin_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 0.0}).xyz
        v.pos *= 1.2
    }
}

animate_player_vertices_rolling :: proc(vertices: []Vertex, state: Player_States, velocity: [3]f32, spike_compression: f32, time: f32) {
    right_vec := la.cross([3]f32{0, 1, 0}, la.normalize0(velocity)) 
    stretch_dir := la.normalize(-la.normalize(velocity) - {0, 0.5, 0})
    for &v, idx in vertices {
        if v.uv.x == 1.0 {
            norm_pos := la.normalize(v.pos - (la.dot(v.pos, right_vec) * right_vec * 0.5))
            down_alignment := max(0.25, min(0.75, la.dot(norm_pos, [3]f32{0, -1, 0})))
            down_alignment = (down_alignment - 0.25) / 0.5

            stretch_alignment := max(0.5, min(1.0, la.dot(norm_pos, stretch_dir)))
            stretch_alignment = (stretch_alignment - 0.5) / 0.5
            stretch_amt := stretch_alignment * stretch_alignment * la.length(velocity) / 40.0

            v.pos *= (1.0 - down_alignment * 0.5)
            v.pos *= 1.0 + stretch_amt
        } else {
            v.pos *= f32(spike_compression)
        }
        v.pos *= 1.2
    }
}

animate_player_vertices_jumping :: proc(vertices: []Vertex) {
    for &v, idx in vertices {
        if v.uv.x == 1.0 {
            v.pos *= 1.25
        }
    }
}

apply_player_vertices_physics_displacement :: proc(vertices: []Vertex, particle_displacement: [3]f32, sliding: bool) {
    displacement_dir := la.normalize0(particle_displacement)
    for &v, idx in vertices {
        displacement_fact := la.dot(displacement_dir, la.normalize0(v.pos))
        if displacement_fact > 0.25 {
            displacement_fact *= 0.5
        }
        if !sliding {
            v.pos = la.clamp_length(v.pos + particle_displacement * displacement_fact * 0.030, 3.0)
            v.pos += particle_displacement * displacement_fact * 0.030
        }
    }
}

apply_player_vertices_roll_rotation :: proc(vertices: []Vertex, velocity: [3]f32, time: f32) {
    for &v, idx in vertices {
        vel_dir: [3]f32 = velocity.xz == 0 ? {0, 0, -1} : la.normalize0(velocity)
        rot_mat := la.matrix4_rotate_f32(f32(time) / 100, la.cross([3]f32{0, 1, 0}, vel_dir))
        v.pos = la.matrix_mul_vector(rot_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 0.0}).xyz
    }
}

