package main
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "base:runtime"
import "core:fmt"

Component :: struct { type: typeid }

Position :: la.Vector3f32 
Scale :: la.Vector3f32
Rotation :: quaternion128
Shape :: enum{ Triangle, InvertedPyramid, Cube, Sphere, Plane, None }
Velocity :: la.Vector3f32
Active_Shaders :: bit_set[ProgramName; u32]
Level_Geometry_Attributes :: bit_set[Component_Name]

Component_Name :: enum {
    Velocity,
    Position,
    Scale,
    Rotation,
    Shape,
    ActiveShaders,
}

Level_Geometry :: struct {
    velocity: Velocity,
    position: Position,
    rotation: Rotation,
    scale: Scale,
    shape: Shape,
    shaders: Active_Shaders,
    attributes: Level_Geometry_Attributes 
}

Level_Geometry_State :: #soa[dynamic]Level_Geometry
