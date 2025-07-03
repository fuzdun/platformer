package state

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import ft "shared:freetype"

import enm "enums"

PLAYER_PARTICLE_STACK_COUNT :: 5
PLAYER_PARTICLE_SECTOR_COUNT :: 10
PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2

Render_State :: struct {
    ft_lib: ft.Library,
    face: ft.Face,

    char_tex_map: map[rune]Char_Tex,

    standard_vao: u32,
    particle_vao: u32,
    background_vao: u32,
    lines_vao: u32,
    text_vao: u32,

    standard_ebo: u32,
    background_ebo: u32,

    standard_vbo: u32,
    particle_vbo: u32,
    particle_pos_vbo: u32,
    background_vbo: u32,
    editor_lines_vbo: u32,
    text_vbo: u32,

    indirect_buffer: u32,

    transforms_ssbo: u32,
    z_widths_ssbo: u32,

    dither_tex: u32,

    static_transforms: [dynamic]glm.mat4,
    player_particle_poss: [dynamic]glm.vec3,
    z_widths: [dynamic]f32,
    shader_render_queues: Shader_Render_Queues,
    player_particles: [PLAYER_PARTICLE_COUNT][4]f32,
    vertex_offsets: Vertex_Offsets,
    index_offsets: Index_Offsets,
    player_vertex_offset: u32,
    player_index_offset: u32,
    render_group_offsets: [len(enm.ProgramName) * len(enm.SHAPE)]u32,

    player_geometry: Shape_Data,
}

clear_render_state :: proc(rs: ^Render_State) {
    clear(&rs.static_transforms)
    clear(&rs.z_widths)
    for &off in rs.render_group_offsets {
        off = 0
    }
}

clear_render_queues :: proc(rs: ^Render_State) {
    for shader in enm.ProgramName {
        clear(&rs.shader_render_queues[shader])
    }
}

free_render_state :: proc(rs: ^Render_State) {
    for shader in enm.ProgramName {
        delete(rs.shader_render_queues[shader])
    }
    delete(rs.static_transforms)
    delete(rs.z_widths)
    ft.done_face(rs.face)
    ft.done_free_type(rs.ft_lib)
    delete(rs.char_tex_map)
    delete(rs.player_geometry.vertices)
    delete(rs.player_geometry.indices)
}


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

