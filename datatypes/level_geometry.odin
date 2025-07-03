package datatypes

import la "core:math/linalg"

import enm "../enums"

Level_Geometry :: struct {
    transform: Transform,
    angular_velocity: la.Vector3f32,
    shape: enm.SHAPE,
    collider: Collider,
    shaders: Active_Shaders,
    attributes: Level_Geometry_Attributes,
    aabb: Aabb,
    ssbo_indexes: [enm.ProgramName]int
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

Shape :: enm.SHAPE

Collider :: enm.SHAPE

Active_Shaders :: bit_set[enm.ProgramName; u64]

Level_Geometry_Attributes :: bit_set[enm.Level_Geometry_Component_Name; u64]

Aabb :: struct{
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32
}

