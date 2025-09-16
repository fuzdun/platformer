package main

import "core:math"
import glm "core:math/linalg/glsl"


// init
INIT_PLAYER_POS :: [3]f32 { 0, 0, 400 }

// move speed
MAX_PLAYER_SPEED: f32: 100.0
MAX_FALL_SPEED: f32: 200.0
AIR_SPEED :: 100.0
SLOPE_SPEED :: 80.0 
P_ACCEL: f32: 150.0
GROUND_BUNNY_V_SPEED: f32: 70
GROUND_BUNNY_H_SPEED: f32: 30
MIN_BUNNY_XZ_VEL: f32: 20.0

DAMAGE_VELOCITY: f32: 1.0
DAMAGE_LEN: f32: 500.0

BREAK_BOOST_VELOCITY: f32: 5.0
BREAK_BOOST_LEN: f32: 250
BOUNCE_VELOCITY: f32: 120.0

// jump
P_JUMP_SPEED: f32: 60.0
WALL_JUMP_FORCE :: 25 
SLOPE_V_JUMP_FORCE :: 50 
SLOPE_JUMP_FORCE :: 40

// forces
GROUND_FRICTION :: 0.01
// GRAV: f32: 135
GRAV: f32: 150
WALL_GRAV: f32: 100 
SLOPE_GRAV: f32: 150 

// input
COYOTE_TIME ::  150
BUNNY_DASH_DEBOUNCE: f32: 400
BUNNY_WINDOW: f32: 100
WALL_DETACH_LEN :: 200

// dash
DASH_SPD: f32: 120.0
DASH_LEN: f32: 220 
DASH_DIST: f32: 15.0

// slide
SLIDE_LEN: f32: 350.0 
SLIDE_SPD: f32: 120
SLIDE_COOLDOWN: f32: 600
SLIDE_ANIM_EASE_LEN: f32: 100

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

ICOSPHERE_SUBDIVISION :: 3 
ICOSPHERE_V_COUNT :: f32(ICOSPHERE_SUBDIVISION + 1) * f32(ICOSPHERE_SUBDIVISION + 2) / 2.0

MIN_SPIKE_COMPRESSION: f32: 0.4
MAX_SPIKE_COMPRESSION: f32: 0.8
SPIKE_COMPRESSION_LERP: f32: 0.10

// geometry crack timing
CRACK_DELAY :: 1000
BREAK_DELAY :: 750


Contact_State :: struct {
    state: Player_States,
    touch_time: f32,
    left_ground: f32,
    left_slope: f32,
    left_wall: f32,
    contact_ray: [3]f32,
    ground_x: [3]f32,
    ground_z: [3]f32,
    last_touched: int
}

Dash_State :: struct {
    dashing: bool,
    dash_start_pos: [3]f32,
    dash_end_pos: [3]f32,
    dash_dir: [3]f32,
    dash_time: f32,
    dash_total: f32,
    can_dash: bool,
}

Slide_State :: struct {
    sliding: bool,
    slide_time: f32,
    slide_total: f32,
    mid_slide_time: f32,
    slide_dir: [3]f32,
    slide_start_pos: [3]f32,
    slide_end_time: f32,
    can_slide: bool
}

Player_State :: struct {
    contact_state: Contact_State,
    dash_state: Dash_State,
    slide_state: Slide_State,

    touch_pt: [3]f32,
    bunny_hop_y: f32,
    dash_hop_debounce_t: f32,

    hurt_t: f32,
    broke_t: f32,

    crunch_pt: [3]f32,
    crunch_pts: [dynamic][4]f32,
    screen_crunch_pt: [2]f32,
    crunch_time: f32,

    position: [3]f32,
    velocity: [3]f32,

    can_press_jump: bool,
    jump_pressed_time: f32,
    jump_held: bool,
    wall_detach_held_t: f32,

    prev_position: [3]f32,

    trail_sample: [3]glm.vec3,
    prev_trail_sample: [3]glm.vec3,
    trail: RingBuffer(TRAIL_SIZE, [3]f32),

    particle_displacement: [3]f32,
    tgt_particle_displacement: [3]f32,

    spike_compression: f32
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

interpolated_trail :: proc(ps: Player_State, t: f32) -> [3]glm.vec3 {
    return math.lerp(ps.prev_trail_sample, ps.trail_sample, t)
}

interpolated_player_matrix :: proc(ps: Player_State, t: f32) -> matrix[4, 4]f32 {
    i_pos := math.lerp(ps.prev_position, ps.position, t) 
    rot := I_MAT
    offset := glm.mat4Translate({f32(i_pos.x), f32(i_pos.y), f32(i_pos.z)})
    return rot * offset
}

