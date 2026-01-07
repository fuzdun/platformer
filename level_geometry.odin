package main

import "core:math/rand"
import "base:runtime"
import tim "core:time"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"

Level_Geometry_State :: #soa[]Level_Geometry

Level_Geometry :: struct {
    transform: Transform,
    angular_velocity: la.Vector3f32,
    shape: SHAPE,
    collider: SHAPE,
    render_type: Level_Geometry_Render_Type,
    attributes: Level_Geometry_Attributes,
    aabb: Aabb,
    shatter_data: Shatter_Ubo,
    transparency: f32,
}

Position :: la.Vector3f32 

Scale :: la.Vector3f32

Rotation :: quaternion128

Transform :: struct {
    position: Position,
    scale: Scale,
    rotation: Rotation
}

Angular_Velocity :: la.Vector3f32

Active_Shaders :: bit_set[ProgramName; u64]

Aabb :: struct {
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32
}

Level_Geometry_Attributes :: bit_set[Level_Geometry_Component_Name; u64]

Level_Geometry_Component_Name :: enum {
    Collider = 0,
    Velocity = 1,
    Angular_Velocity = 2,
    Crackable = 3,
    Dash_Breakable = 4,
    Hazardous = 5,
    Slide_Zone = 6,
    Breakable = 7,
    Bouncy = 8
}

move_geometry :: proc (lgs: ^Level_Geometry_State, phs: ^Physics_State, player_pos: ^[3]f32, cts: Contact_State, idx: int) {
    runtime.random_generator_reset_u64(context.random_generator, u64(idx) + u64(SEED))
    x_dir := (rnd.float32() - 0.5) * 0.5
    y_dir := (rnd.float32() - 0.5) * 0.5
    lg := &lgs[idx]
    lg.transform.position.x += x_dir 
    lg.transform.position.y += y_dir 
    vertices_len := len(phs.level_colliders[lg.shape].vertices)
    trans_mat := trans_to_mat4(lg.transform)

    if cts.state != .IN_AIR && idx == cts.last_touched {
        player_pos.x += x_dir
        player_pos.y += y_dir
    }
}

