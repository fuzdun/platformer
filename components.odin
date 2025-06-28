package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "base:runtime"
import "core:fmt"

// =======================
// LEVEL GEOMETRY ENTITIES
// =======================

// Attributes
Level_Geometry_Component_Name :: enum {
    Transform = 0,
    Shape = 1,
    Collider = 2,
    Active_Shaders = 3,
    Angular_Velocity = 4 
}

// Schema
// 0 = Transform
// 1 = Shape
// 2 = Collider
// 3 = Active_Shaders
// 4 = Angular_Velocity

// Component typedefs
make_transform :: proc(
    position: Position = {0, 0, 0},
    scale: Scale = {1, 1, 1},
    rotation: Rotation = quaternion(real=0, imag=0, jmag=0, kmag=0)
) -> Transform {
    return {position, scale, rotation}
}

Position :: la.Vector3f32 
Scale :: la.Vector3f32
Rotation :: quaternion128
Transform :: struct{
    position: Position,
    scale: Scale,
    rotation: Rotation
}
Angular_Velocity :: la.Vector3f32
Shape :: SHAPE
Collider :: SHAPE
Active_Shaders :: bit_set[ProgramName; u64]
Level_Geometry_Attributes :: bit_set[Level_Geometry_Component_Name; u64]

// Entity struct
Level_Geometry :: struct {
    transform: Transform,
    angular_velocity: la.Vector3f32,
    shape: SHAPE,
    collider: Collider,
    shaders: Active_Shaders,
    attributes: Level_Geometry_Attributes,
    aabb: AABB,
    ssbo_indexes: [ProgramName]int
}

// AOS -> SOA
Level_Geometry_State :: #soa[dynamic]Level_Geometry

// ==============
// OTHER ENTITIES
// ==============

// etc
