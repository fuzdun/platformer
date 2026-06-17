package main

import la "core:math/linalg"
import hm "core:container/handle_map"

CHUNK_WIDTH :: 500
CHUNK_DEPTH :: 500

BEAT_SPACE :: 110

Handle :: distinct hm.Handle32
Null_Handle :: Handle { idx = 0, gen = 0 }
Level_Geometry_State :: hm.Dynamic_Handle_Map(Entity, Handle)

Entity :: struct {
    handle: Handle,
    transform: Transform,
    shape: SHAPE,
    collider: SHAPE,
    render_type: Level_Geometry_Render_Type,
    attributes: Level_Geometry_Attributes,
    transparency: f32,
    jump_block: f32,
    variant: Variant 
}

Variant :: union { Shatter_Block, Other }

Shatter_Block :: struct {
    shatter_data: Shatter_Ubo,
}

Other :: struct {}

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

Level_Geometry_Attributes :: bit_set[Level_Geometry_Component; u64]

Level_Geometry_Component :: enum {
    Collider = 0,
    Crackable = 3,
    Dash_Breakable = 4,
    Hazardous = 5,
    Slide_Zone = 6,
    Breakable = 7,
    Bouncy = 8
}

Level_Geometry_Component_Name :: #sparse[Level_Geometry_Component]string {
    .Collider = "collider",
    .Crackable = "crackable",
    .Dash_Breakable = "dash_Breakable",
    .Hazardous = "hazardous",
    .Slide_Zone = "slide_Zone",
    .Breakable = "breakable",
    .Bouncy = "bouncy"
}

