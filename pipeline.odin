package main
import glm "core:math/linalg/glsl"


// #####################################################
// Render Pipeline Config 
// #####################################################
Ssbo :: enum {
    Transform,
    Transparency,
    Shatter,
    Z_Width,
    Jump_Block
}

Ssbo_Info :: [Ssbo]struct{ type_sz: int, loc: u32 } {
    .Transform    = { size_of(glm.mat4),         4},
    .Z_Width      = { size_of(Z_Width_Ubo),      5},
    .Shatter      = { size_of(Shatter_Ubo),      6},
    .Transparency = { size_of(Transparency_Ubo), 7},
    .Jump_Block   = { size_of(f32),              8}
}

