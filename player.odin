package main

import "core:math"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"


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
// SLIDE_SPD: f32: 20
SLIDE_COOLDOWN: f32: 600
SLIDE_ANIM_EASE_LEN: f32: 100

// physics
CONTACT_RAY_LEN ::  2.0
CONTACT_RAY_LEN2 :: CONTACT_RAY_LEN * CONTACT_RAY_LEN
GROUND_BUFFER: f32 = 0.1 

// rendering
PARTICLE_DISPLACEMENT_LERP :: 0.25
TGT_PARTICLE_DISPLACEMENT_LERP :: 0.4
PLAYER_PARTICLE_STACK_COUNT :: 8 
PLAYER_PARTICLE_SECTOR_COUNT :: 16
PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2
PLAYER_SPIN_PARTICLE_ARM_COUNT :: 5 
PLAYER_SPIN_PARTICLE_ARM_LEN :: 10
// PLAYER_SPIN_PARTICLE_COUNT :: PLAYER_SPIN_PARTICLE_ARM_COUNT * PLAYER_SPIN_PARTICLE_ARM_LEN
PLAYER_SPIN_PARTICLE_COUNT :: 3360
PLAYER_SPIN_TAIL_INTERVAL :: f32(math.PI) * 2.0 / PLAYER_SPIN_PARTICLE_ARM_COUNT

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

Spin_State :: struct {
    spinning: bool,
    spin_time: f32,
    spin_dir: [2]f32
}

Player_State :: struct {
    contact_state: Contact_State,
    dash_state: Dash_State,
    slide_state: Slide_State,
    spin_state: Spin_State, 

    touch_pt: [3]f32,
    bunny_hop_y: f32,
    dash_hop_debounce_t: f32,

    hurt_t: f32,
    broke_t: f32,

    crunch_pt: [3]f32,
    screen_splashes: [dynamic][4]f32,
    screen_ripple_pt: [2]f32,
    crunch_time: f32,

    position: [3]f32,
    velocity: [3]f32,

    ground_x: [3]f32,
    ground_z: [3]f32,

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

animate_player_vertices_sliding :: proc(vertices: []Vertex, contact_ray: [3]f32, slide_total: f32, slide_off: f32, time: f32) {
    up := la.normalize(contact_ray)
    spin_mat := la.matrix4_rotate_f32(f32(time) / 150, up)
    slide_t := slide_total
    end_slide_t := (slide_total - slide_off) - (SLIDE_LEN - SLIDE_ANIM_EASE_LEN)
    compression_t := clamp(slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0) - clamp(end_slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0)
    for &v, idx in vertices {
        vertical_fact := la.dot(up, v.pos)
        v.pos -= up * vertical_fact * easeout_cubic(compression_t) * abs(vertical_fact) * 1.2
        if v.uv.x == 1.0 {
            v.pos *= (1.0 + (compression_t) * 4.0)
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
