package main

import "core:math"
import "core:slice"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import ft "shared:freetype"

//UBO_VEC3_SIZE :: size_of(glm.vec4)

I_MAT :: glm.mat4(1.0)

SHAPE :: enum {
    CUBE,
    WEIRD,
}

SHAPE_FILENAME := [SHAPE]string {
    .CUBE = "basic_cube",
    .WEIRD = "weird"
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

    common_ubo: u32,
    dash_ubo: u32,
    ppos_ubo: u32,

    dither_tex: u32,

    player_draw_command: [1]gl.DrawElementsIndirectCommand,

    player_particle_poss: [dynamic]glm.vec3,
    player_particles: [PLAYER_PARTICLE_COUNT][4]f32,
    player_geometry: Shape_Data,

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
    b_uv: glm.vec2,
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
    t: f32
}

Shape_Data :: struct{
    vertices: []Vertex,
    indices: []u32
}

Vertex_Offsets :: [len(SHAPE)]u32

Index_Offsets :: [len(SHAPE)]u32

Shader_Render_Queues :: [ProgramName][dynamic]gl.DrawElementsIndirectCommand

Lg_Render_Data :: struct {
    render_group: int,
    transform_mat: glm.mat4,
    z_width: f32,
}

Level_Geometry_Render_Type :: enum {
    Standard,
    Dither_Test
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

free_render_state :: proc(rs: ^Render_State) {
    ft.done_face(rs.face)
    ft.done_free_type(rs.ft_lib)
    delete(rs.char_tex_map)
    delete(rs.player_geometry.vertices)
    delete(rs.player_geometry.indices)
}

add_player_sphere_data :: proc(rs: ^Render_State) {
    vertical_count := SPHERE_STACK_COUNT
    horizontal_count := SPHERE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u32
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count)
    horizontal_step := (2 * PI) / f32(horizontal_count)

    rs.player_geometry.vertices = make([]Vertex, SPHERE_V_COUNT)
    vertices := &rs.player_geometry.vertices
    for i in 0..=vertical_count {
        vertical_angle = PI / 2.0 - f32(i) * vertical_step 
        xz := CORE_RADIUS * math.cos(vertical_angle)
        y = CORE_RADIUS * math.sin(vertical_angle)

        for j in 0..=horizontal_count {
            v : Vertex
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
    rs.player_geometry.indices = make([]u32, SPHERE_I_COUNT)
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


update_vertices :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, rs: ^Render_State) {
    // if len(lgs.dirty_entities) > 0 {
    //     for lg_idx in lgs.dirty_entities {
    //         lg := lgs.entities[lg_idx]
    //         trans_mat := trans_to_mat4(lg.transform)
    //         max_z := min(f32)
    //         min_z := max(f32)
    //         for v in sr[lg.shape].vertices {
    //             new_pos := trans_mat * [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}
    //             max_z = max(new_pos.z, max_z)
    //             min_z = min(new_pos.z, min_z)
    //         }

            // for offset, shader in lg.ssbo_indexes {
            //     if offset != -1 {
                    //ssbo_idx := get_ssbo_idx(lg, shader, rs^)
                    // group_idx := int(shader) * len(SHAPE) + int(lg.shape)
                    // group_offset := rs.render_group_offsets[group_idx]
                    // ssbo_idx := int(group_offset) + lg.ssbo_indexes[shader]
                    // if ssbo_idx > len(rs.static_transforms) - 1 {
                    //     append(&rs.static_transforms, trans_mat) 
                    //     append(&rs.z_widths, max_z - min_z)
                    // } else {
                    //     rs.static_transforms[ssbo_idx] = trans_mat
                    //     rs.z_widths[ssbo_idx] = max_z - min_z
                    // }
                // }
            // }
    //     }
    // }
    // clear(&lgs.dirty_entities)
    //slice.sort_by(rs.static_transforms[:], proc(a: glm.mat4, b: glm.mat4) -> bool { return a[3][2] < b[3][2] })
}

update_player_particles :: proc(rs: ^Render_State, ps: Player_State, time: f32) {
    vertical_count := PLAYER_PARTICLE_STACK_COUNT
    horizontal_count := PLAYER_PARTICLE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u32
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count + 1)
    horizontal_step := (2 * PI) / f32(horizontal_count)
    sphere_rotate := la.matrix3_from_euler_angles(time / 300, time / 300, 0, .XYZ)
    // sphere_rotate := la.matrix3_from_euler_angles(f32(0), f32(0), f32(0), .XYZ)
    for i in 0..<vertical_count {
        vertical_angle = PI / 2.0 - f32(i + 1) * vertical_step
        xz := PLAYER_SPHERE_RADIUS * math.cos(vertical_angle)
        y = PLAYER_SPHERE_RADIUS * math.sin(vertical_angle)
        for j in 0..<horizontal_count {
            id := i * horizontal_count + j
            horizontal_angle = f32(j) * horizontal_step
            x = xz * math.cos(horizontal_angle)
            z = xz * math.sin(horizontal_angle)
            // pos: [4]f32 = {x, y, z, f32(id)}
            pos: [4]f32 = {x, y, z, f32(id)}
            pos.xyz = sphere_rotate * pos.xyz * 2.0

            displacement_fact := la.dot(ps.particle_displacement, pos.xyz)
            if displacement_fact > 0 {
                displacement_fact *= 0.2
            }
            pos.xyz += la.clamp_length(ps.particle_displacement * displacement_fact * 0.0010, 20.0)

            rs.player_particles[i * horizontal_count + j] = pos
        }
    }
    end_idx := vertical_count * horizontal_count
    top_pt: [4]f32 = {0, PLAYER_SPHERE_RADIUS * 2.0, 0, f32(end_idx)}
    bot_pt: [4]f32 = {0, -PLAYER_SPHERE_RADIUS * 2.0, 0, f32(end_idx + 1)}
    top_pt.xyz = sphere_rotate * top_pt.xyz
    bot_pt.xyz = sphere_rotate * bot_pt.xyz
    rs.player_particles[end_idx] = top_pt
    rs.player_particles[end_idx + 1] = bot_pt
    
    for &p in rs.player_particles {
        constrain_proj: [3]f32 = ps.dash_dir * la.dot(ps.dash_dir, p.xyz)
        constrained_pos := p.xyz - constrain_proj
        dash_pos_t := la.length(ps.dash_dir - constrain_proj) / 2.0
        constrain_start_t := ps.dash_time + 50.0 * dash_pos_t
        constrain_amt := 1.0 - easeout(clamp((time - constrain_start_t) / 75.0, 0.0, 1.0))
        if (time - ps.dash_time > 200) {
            constrain_amt = 1.0;
        }
        constrained_pos *= constrain_amt;
        constrained_pos += constrain_proj;
        //constrained_pos += constrain_proj * (1.0 - constrain_amt) * 2.5 + ps.dash_dir * 2.5 * (1.0 - constrain_amt);
        p = {constrained_pos.x, constrained_pos.y, constrained_pos.z, p.w}
    }

    z_sort := proc(a: [4]f32, b: [4]f32) -> bool { return a.z < b.z }
    slice.sort_by(rs.player_particles[:], z_sort)
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
            {{x_off,     y_off,     0, 1},     {0, 1}},
            {{x_off + w, y_off,     0, 1},     {1, 1}},
            {{x_off,     y_off + h, 0, 1},     {0, 0}},
            {{x_off + w, y_off + h, 0, 1},     {1, 0}},
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


