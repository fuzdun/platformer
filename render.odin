package main

import "core:math"
import "core:slice"
import "core:fmt"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import ft "shared:freetype"
import rand "core:math/rand"

//UBO_VEC3_SIZE :: size_of(glm.vec4)

OUTER_TESSELLATION_AMT :: 6.0
INNER_TESSELLATION_AMT :: 4.0
// OUTER_TESSELLATION_AMT :: 20.0
// INNER_TESSELLATION_AMT :: 10.0

I_MAT :: glm.mat4(1.0)

SHAPE :: enum {
    CUBE,
    CYLINDER,
    ICO,
    DASH_BARRIER,
    SLIDE_ZONE
}

SHAPE_FILENAME := [SHAPE]string {
    .CUBE = "basic_cube",
    .CYLINDER = "cylinder",
    .ICO = "icosphere",
    .DASH_BARRIER = "dash_barrier",
    .SLIDE_ZONE = "slide_zone"
}

TEXT_VERTICES :: [4]Quad_Vertex4 {
    {{-1, -1, 0, 1}, {0, 0}},
    {{1, -1, 0, 1}, {1, 0}},
    {{-1, 1, 0, 1}, {0, 1}},
    {{1, 1, 0, 1}, {1, 1}}
}

BACKGROUND_VERTICES :: [4]Quad_Vertex {
    {{-1, -1, -1}, {0, 0}},
    {{1, -1, -1}, {1, 0}},
    {{-1, 1, -1}, {0, 1}},
    {{1, 1, -1}, {1, 1}},
}

PARTICLE_VERTICES :: [4]Quad_Vertex {
    {{-0.7, -0.7, 0.0}, {0, 0}},
    {{0.7, -0.7, 0.0}, {1, 0}},
    {{-0.7, 0.7, 0.0}, {0, 1}},
    {{0.7, 0.7, 0.0}, {1, 1}},
}

Render_State :: struct {
    postprocessing_fbo: u32,
    postprocessing_tcb: u32,
    postprocessing_rbo: u32,

    ft_lib: ft.Library,
    face: ft.Face,

    char_tex_map: map[rune]Char_Tex,

    standard_vao: u32,
    particle_vao: u32,
    background_vao: u32,
    lines_vao: u32,
    text_vao: u32,
    player_vao: u32,

    standard_ebo: u32,
    background_ebo: u32,
    player_fill_ebo: u32,
    player_outline_ebo: u32,

    standard_vbo: u32,
    player_vbo: u32,
    particle_vbo: u32,
    particle_pos_vbo: u32,
    background_vbo: u32,
    editor_lines_vbo: u32,
    text_vbo: u32,

    indirect_buffer: u32,

    transforms_ssbo: u32,
    z_widths_ssbo: u32,
    crack_time_ssbo: u32,
    break_data_ssbo: u32,

    common_ubo: u32,
    dash_ubo: u32,
    ppos_ubo: u32,
    tess_ubo: u32,

    dither_tex: u32,

    player_draw_command: [1]gl.DrawElementsIndirectCommand,

    player_particle_poss: [dynamic]glm.vec3,
    player_particles: [PLAYER_PARTICLE_COUNT][4]f32,
    player_geometry: Shape_Data,
    player_outline_indices: []u32,
    player_fill_indices: []u32,

    vertex_offsets: Vertex_Offsets,
    index_offsets: Index_Offsets,
}

Char_Tex :: struct {
    id: u32,
    size: glm.ivec2,
    bearing: glm.ivec2,
    next: u32
}

Vertex :: struct{
    pos: glm.vec3,
    uv: glm.vec2,
    normal: glm.vec3
}

Quad_Vertex :: struct {
    position: glm.vec3,
    uv: glm.vec2
}

Quad_Vertex4 :: struct {
    position: glm.vec4,
    uv: glm.vec2
}

Line_Vertex :: struct {
    position: glm.vec3,
    t: f32,
    color: glm.vec3
}

Shape_Data :: struct{
    vertices: []Vertex,
    indices: []u32
}

Vertex_Offsets :: [len(SHAPE)]u32

Index_Offsets :: [len(SHAPE)]u32

Break_Data :: struct {
    time: f32,
    pos: [3]f32,
    dir: [3]f32
}

Lg_Render_Data :: struct {
    render_group: int,
    transform_mat: glm.mat4,
    z_width: f32,
    crack_time: f32,
    break_data: Break_Data
}

Level_Geometry_Render_Type :: enum {
    Standard,
    Dither_Test,
    Dash_Barrier
}

Common_Ubo :: struct {
    projection: glm.mat4,
    time: f32
}

Dash_Ubo :: struct {
    dash_time: f32,
    dash_end_time: f32,
    constrain_dir: glm.vec3,
}

Tess_Ubo :: struct {
    inner_amt: f32,
    outer_amt: f32
}

Render_Groups :: [Level_Geometry_Render_Type][dynamic]gl.DrawElementsIndirectCommand 

free_render_state :: proc(rs: ^Render_State) {
    ft.done_face(rs.face)
    ft.done_free_type(rs.ft_lib)
    delete(rs.char_tex_map)
    delete(rs.player_geometry.vertices)
    delete(rs.player_geometry.indices)
    delete(rs.player_fill_indices)
    delete(rs.player_outline_indices)
}


render_text :: proc(shst: ^Shader_State, rs: ^Render_State, text: string, pos: [3]f32, cam_up: [3]f32, cam_right: [3]f32, scale: f32) {
    x: f32 = 0
    trans_mat: = la.matrix4_translate(pos)
    set_matrix_uniform(shst, "transform", &trans_mat)
    for c in str.trim_null(text) {
        char_tex := rs.char_tex_map[c]
        x_off := x + f32(char_tex.bearing.x) * scale
        y_off := -f32(char_tex.size.y - char_tex.bearing.y) * scale
        w := f32(char_tex.size.x) * scale
        h := f32(char_tex.size.y) * scale

        vertices := [4]Quad_Vertex4 {
            {{x_off,     y_off,     0, 1}, {0, 1}},
            {{x_off + w, y_off,     0, 1}, {1, 1}},
            {{x_off,     y_off + h, 0, 1}, {0, 0}},
            {{x_off + w, y_off + h, 0, 1}, {1, 0}},
        }
        for &v in vertices {
            v.position.xyz = cam_right * v.position.x + cam_up * v.position.y
        }
        gl.BindTexture(gl.TEXTURE_2D, char_tex.id)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.text_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    
        x += f32(char_tex.next >> 6) * scale
    } 
}

render_screen_text :: proc(shst: ^Shader_State, rs: ^Render_State, text: string, pos: [3]f32, proj: glm.mat4, scale: f32) {
    screen_pos := proj * [4]f32 {pos.x, pos.y, pos.z, 1}
    screen_pos /= screen_pos.w
    x := screen_pos.x
    y := screen_pos.y + .05
    for c in str.trim_null(text) {
        char_tex := rs.char_tex_map[c]
        x_off := x + (f32(char_tex.bearing.x) * scale) / WIDTH
        y_off := y + (-f32(char_tex.size.y - char_tex.bearing.y) * scale) / HEIGHT
        w := (f32(char_tex.size.x) * scale) / WIDTH
        h := (f32(char_tex.size.y) * scale) / HEIGHT

        vertices := [4]Quad_Vertex4 {
            {{x_off,     y_off,     0, 1}, {0, 1}},
            {{x_off + w, y_off,     0, 1}, {1, 1}},
            {{x_off,     y_off + h, 0, 1}, {0, 0}},
            {{x_off + w, y_off + h, 0, 1}, {1, 0}},
        }
        gl.BindTexture(gl.TEXTURE_2D, char_tex.id)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.text_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        x += (f32(char_tex.next >> 6) * scale) / WIDTH
    } 
}

draw_indirect_render_queue :: proc(rs: Render_State, queue: []gl.DrawElementsIndirectCommand, mode: u32) {
    if len(queue) > 0 {
        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, rs.indirect_buffer)
        gl.BufferData(gl.DRAW_INDIRECT_BUFFER, size_of(queue[0]) * len(queue), raw_data(queue), gl.DYNAMIC_DRAW)
        gl.MultiDrawElementsIndirect(mode, gl.UNSIGNED_INT, nil, i32(len(queue)), 0)
    }
}

trans_to_mat4 :: proc(trns: Transform) -> glm.mat4 {
    off := glm.mat4Translate(trns.position)
    rot := glm.mat4FromQuat(trns.rotation)
    scale := glm.mat4Scale(trns.scale)
    return off * rot * scale
}

easeout_cubic :: proc(n: f32) -> f32 {
    return 1.0 - math.pow(1.0 - n, 3);
}

easeout :: proc(n: f32) -> f32 {
    return math.sin(n * math.PI / 2.0);
}

counts_to_offsets :: proc(arr: []int) {
    for &val, idx in arr[1:] {
       val += arr[idx] 
    }
    #reverse for &val, idx in arr {
        val = idx == 0 ? 0 : arr[idx - 1]
    }
}


