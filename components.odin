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
    Velocity,
    Position,
    Scale,
    Rotation,
    Shape,
    ShapeString,
    Colliding,
    ActiveShaders,
}

// Component typedefs
Position :: la.Vector3f32 
Scale :: la.Vector3f32
Rotation :: quaternion128
Shape :: enum{ Triangle, InvertedPyramid, Cube, Sphere, Plane, None }
ShapeString :: string
Velocity :: la.Vector3f32
Active_Shaders :: bit_set[ProgramName; u32]
Level_Geometry_Attributes :: bit_set[Level_Geometry_Component_Name]

// Entity struct
Level_Geometry :: struct {
    velocity: Velocity,
    position: Position,
    rotation: Rotation,
    scale: Scale,
    shape: Shape,
    shape_string: ShapeString,
    shaders: Active_Shaders,
    attributes: Level_Geometry_Attributes 
}

// AOS -> SOA
Level_Geometry_State :: #soa[dynamic]Level_Geometry

// ==============
// OTHER ENTITIES
// ==============

// etc
