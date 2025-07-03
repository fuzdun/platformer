package state

import glm "core:math/linalg/glsl"

import enm "../enums"
import const "../constants"

Player_State :: struct {
    state: enm.Player_States,
    dash_start_pos: [3]f32,
    dash_end_pos: [3]f32,
    dash_dir: [3]f32,
    touch_pt: [3]f32,
    touch_time: f32,
    crunch_pt: [3]f32,
    bunny_hop_y: f32,
    crunch_time: f32,
    last_dash: f32,

    position: [3]f32,
    velocity: [3]f32,

    can_press_jump: bool,
    can_press_dash: bool,
    jump_pressed_time: f32,
    dash_time: f32,
    dash_end_time: f32,
    dashing: bool,

    left_ground: f32,
    left_slope: f32,
    left_wall: f32,

    contact_ray: [3]f32,
    ground_x: [3]f32,
    ground_z: [3]f32,
    prev_position: [3]f32,

    trail_sample: [3]glm.vec3,
    prev_trail_sample: [3]glm.vec3,
    trail: RingBuffer(const.TRAIL_SIZE, [3]f32),

    particle_displacement: [3]f32,
    tgt_particle_displacement: [3]f32
}

free_player_state :: proc(ps: ^Player_State) {}

