package main

import "core:math"
import glm "core:math/linalg/glsl"


// init
INIT_PLAYER_POS :: [3]f32 { 0, 0, 0 }

// move speed
MAX_PLAYER_SPEED: f32: 50.0
MAX_FALL_SPEED: f32: 60.0
AIR_SPEED :: 100.0
SLOPE_SPEED :: 80.0 
P_ACCEL: f32: 150.0
GROUND_BUNNY_V_SPEED: f32: 70
GROUND_BUNNY_H_SPEED: f32: 30
MIN_BUNNY_XZ_VEL: f32: 20.0

// jump
P_JUMP_SPEED: f32: 60.0
WALL_JUMP_FORCE :: 25 
SLOPE_V_JUMP_FORCE :: 50 
SLOPE_JUMP_FORCE :: 40

// forces
GROUND_FRICTION :: 0.05
GRAV: f32: 135
WALL_GRAV: f32: 20 
SLOPE_GRAV: f32: 60 

// input
COYOTE_TIME ::  150
BUNNY_DASH_DEBOUNCE: f32: 400
BUNNY_WINDOW: f32: 100

// dash
DASH_SPD: f32: 75.0
DASH_LEN: f32: 175 
DASH_DIST: f32: 15.0

// physics
GROUND_RAY_LEN ::  2.0
GROUNDED_RADIUS: f32: 0.01 
GROUNDED_RADIUS2 :: GROUNDED_RADIUS * GROUNDED_RADIUS
GROUND_OFFSET: f32 = 1.0 

// rendering
PARTICLE_DISPLACEMENT_LERP :: 0.25
TGT_PARTICLE_DISPLACEMENT_LERP :: 0.4
PLAYER_PARTICLE_STACK_COUNT :: 8 
PLAYER_PARTICLE_SECTOR_COUNT :: 16
PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2

// trail history
TRAIL_SIZE :: 50 

// sphere attributes
CORE_RADIUS :: 1.0
PLAYER_SPHERE_RADIUS :: 1.0
PLAYER_SPHERE_SQ_RADIUS :: PLAYER_SPHERE_RADIUS * PLAYER_SPHERE_RADIUS
SPHERE_SECTOR_COUNT :: 30 
SPHERE_STACK_COUNT :: 20 
SPHERE_V_COUNT :: (SPHERE_STACK_COUNT + 1) * (SPHERE_SECTOR_COUNT + 1)
SPHERE_I_COUNT :: (SPHERE_STACK_COUNT - 1) * SPHERE_SECTOR_COUNT * 6 

Player_State :: struct {
    state: Player_States,
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
    trail: RingBuffer(TRAIL_SIZE, [3]f32),

    particle_displacement: [3]f32,
    tgt_particle_displacement: [3]f32,

    anim_angle: f32
}

free_player_state :: proc(ps: ^Player_State) {}

Player_States :: enum {
    ON_GROUND,
    ON_WALL,
    ON_SLOPE,
    IN_AIR,
    DASHING 
}

interpolated_player_pos :: proc(ps: Player_State, t: f32) -> [3]f32 {
    return math.lerp(ps.prev_position, ps.position, t) 
}

interpolated_trail :: proc(ps: Player_State, t: f32) -> [3]glm.vec3 {
    return math.lerp(ps.prev_trail_sample, ps.trail_sample, t)
}

interpolated_player_matrix :: proc(ps: Player_State, t: f32) -> matrix[4, 4]f32 {
    i_pos := math.lerp(ps.prev_position, ps.position, t) 
    rot := I_MAT
    offset := glm.mat4Translate({f32(i_pos.x), f32(i_pos.y), f32(i_pos.z)})
    return rot * offset
}

