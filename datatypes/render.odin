package datatypes
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import enm "../enums"

Shader_Render_Queues :: [enm.ProgramName][dynamic]gl.DrawElementsIndirectCommand

Vertex_Offsets :: [len(enm.SHAPE)]u32
Index_Offsets :: [len(enm.SHAPE)]u32


Char_Tex :: struct {
    id: u32,
    size: glm.ivec2,
    bearing: glm.ivec2,
    next: u32
}

Quad_Vertex :: struct {
    position: glm.vec3,
    uv: glm.vec2
}

Line_Vertex :: struct {
    position: glm.vec3,
    t: f32
}

Quad_Vertex4 :: struct {
    position: glm.vec4,
    uv: glm.vec2
}

Vertex :: struct{
    pos: glm.vec3,
    uv: glm.vec2,
    b_uv: glm.vec2,
    normal: glm.vec3
}

Renderable :: struct{
    transform: glm.mat4,
    z_width: f32
}


