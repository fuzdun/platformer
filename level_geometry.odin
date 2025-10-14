package main

import la "core:math/linalg"
import glm "core:math/linalg/glsl"


Level_Geometry_State :: #soa[]Level_Geometry
//Level_Geometry_State :: #soa[]Level_Geometry

free_level_geometry_state :: proc(lgs: ^Level_Geometry_State) {}

//Level_Geometry_Soa :: #soa[dynamic]Level_Geometry
//Level_Geometry_Soa :: #soa[]Level_Geometry

Level_Geometry :: struct {
    transform: Transform,
    angular_velocity: la.Vector3f32,
    shape: SHAPE,
    collider: Collider,
    render_type: Level_Geometry_Render_Type,
    attributes: Level_Geometry_Attributes,
    aabb: Aabb,
    crack_time: f32,
    break_data: Break_Data,
    transparency: f32
}

Transform :: struct{
    position: Position,
    scale: Scale,
    rotation: Rotation
}

Position :: la.Vector3f32 

Scale :: la.Vector3f32

Rotation :: quaternion128

Angular_Velocity :: la.Vector3f32

Shape :: SHAPE

Collider :: SHAPE

Active_Shaders :: bit_set[ProgramName; u64]

Level_Geometry_Attributes :: bit_set[Level_Geometry_Component_Name; u64]

Aabb :: struct{
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32
}

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

