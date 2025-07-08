package state

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import ft "shared:freetype"
import "core:math"

import enm "../enums"
import const "../constants"
import typ "../datatypes"
import st "../state"

Render_State :: struct {
    ft_lib: ft.Library,
    face: ft.Face,

    char_tex_map: map[rune]typ.Char_Tex,

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
    shader_render_queues: typ.Shader_Render_Queues,
    player_particles: [const.PLAYER_PARTICLE_COUNT][4]f32,
    vertex_offsets: typ.Vertex_Offsets,
    index_offsets: typ.Index_Offsets,
    player_vertex_offset: u32,
    player_index_offset: u32,
    render_group_offsets: [len(enm.ProgramName) * len(enm.SHAPE)]u32,

    player_geometry: typ.Shape_Data,
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

add_player_sphere_data :: proc(rs: ^st.Render_State) {
    vertical_count := const.SPHERE_STACK_COUNT
    horizontal_count := const.SPHERE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u32
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count)
    horizontal_step := (2 * PI) / f32(horizontal_count)

    rs.player_geometry.vertices = make([]typ.Vertex, const.SPHERE_V_COUNT)
    vertices := &rs.player_geometry.vertices
    for i in 0..=vertical_count {
        vertical_angle = PI / 2.0 - f32(i) * vertical_step 
        xz := const.CORE_RADIUS * math.cos(vertical_angle)
        y = const.CORE_RADIUS * math.sin(vertical_angle)

        for j in 0..=horizontal_count {
            v : typ.Vertex
            horizontal_angle = f32(j) * horizontal_step 
            x = xz * math.cos(horizontal_angle)
            z = xz * math.sin(horizontal_angle)
            v.pos = {x, y, z}
            uv: glm.vec2 = {f32(j) / f32(horizontal_count), f32(i) / f32(vertical_count)}
            v.uv = uv
            v.b_uv = uv
            vertices[(horizontal_count + 1) * i + j] = v
        }
    }

    ind := 0
    rs.player_geometry.indices = make([]u32, const.SPHERE_I_COUNT)
    indices := &rs.player_geometry.indices
    for i in 0..<vertical_count {
        vr1 = u32(i * (horizontal_count + 1))
        vr2 = vr1 + u32(horizontal_count) + 1

        for j := 0; j < horizontal_count; {
            if i != 0 {
                indices[ind] = vr1
                indices[ind+1] = vr2
                indices[ind+2] = vr1+1
                ind += 3
            }
            if i != vertical_count - 1 {
                indices[ind] = vr1 + 1
                indices[ind+1] = vr2
                indices[ind+2] = vr2 + 1
                ind += 3
            }
            //append(&outline_indices, vr1, vr2)
            if i != 0 {
                //append(&outline_indices, vr1, vr1 + 1)
            }
            j += 1 
            vr1 += 1
            vr2 += 1
        }
    }
}

