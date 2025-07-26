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

    common_ubo: u32,
    dash_ubo: u32,
    ppos_ubo: u32,

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
    crack_time: f32
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
    delete(rs.player_fill_indices)
    delete(rs.player_outline_indices)
}

ICO_H_ANGLE :: math.PI / 180 * 72
ICO_V_ANGLE := math.atan(0.5)

new_add_player_sphere_data :: proc(rs: ^Render_State) {
    vertices := make([dynamic]Vertex); defer delete(vertices) 

    hedron_tmp_vertices: [12][3]f32
    hedron_tmp_indices := make([dynamic]int); defer delete(hedron_tmp_indices)

    h_angle_1 := f32(-math.PI / 2 - ICO_H_ANGLE / 2)
    h_angle_2 := f32(-math.PI / 2)

    z := f32(CORE_RADIUS * math.sin(ICO_V_ANGLE))
    xy := f32(CORE_RADIUS * math.cos(ICO_V_ANGLE))

    hedron_tmp_vertices[0] = {0, 0, CORE_RADIUS}
    i0 := 0
    i5 := 11
    for i in 1..=5 {
        hedron_tmp_vertices[i] = {
            xy * math.cos(h_angle_1),
            xy * math.sin(h_angle_1),
            z
        }
        hedron_tmp_vertices[i + 5] = {
            xy * math.cos(h_angle_2),
            xy * math.sin(h_angle_2),
            -z
        }
        h_angle_1 += ICO_H_ANGLE
        h_angle_2 += ICO_H_ANGLE
    }
    hedron_tmp_vertices[11] = {0, 0, -CORE_RADIUS}

    for i in 0..<5 {
        i1 := i + 1
        i2 := i == 4 ? 1 : i + 2
        i3 := i + 6
        i4 := i == 4 ? 6 : i + 7
        append(&hedron_tmp_indices, i0, i1, i2, i1, i3, i2, i2, i3, i4, i3, i5, i4)
    }


    new_vs := make([dynamic]([4]f32)); defer delete(new_vs) // 4th float is for marking spikes
    for i := 0; i < len(hedron_tmp_indices); i += 3 {
        clear(&new_vs)
        v1 := hedron_tmp_vertices[hedron_tmp_indices[i]] 
        v2 := hedron_tmp_vertices[hedron_tmp_indices[i + 1]] 
        v3 := hedron_tmp_vertices[hedron_tmp_indices[i + 2]] 
        append(&new_vs, [4]f32{v1.x, v1.y, v1.z, 1})

        for j in 1..=ICOSPHERE_SUBDIVISION {
            t := f32(j) / f32(ICOSPHERE_SUBDIVISION)
            new_v0 := la.vector_slerp(v1, v2, t)
            new_v1 := la.vector_slerp(v1, v3, t)
            for k in 0..=j {

                spike := (j + k) % 3 == 0 ? 1.0 : 0.0
                new_v: [4]f32
                new_v.w = f32(spike)

                if k == 0 {
                    new_v.xyz = new_v0
                } else if k == j {
                    new_v.xyz = new_v1 
                } else {
                    new_v.xyz = la.vector_slerp(new_v0, new_v1, f32(k) / f32(j))
                }
                append(&new_vs, new_v) 
            }
        }
        for j in 1..=ICOSPHERE_SUBDIVISION {
            for k in 0..<j {
                i1 := int(math.floor((f32(j) - 1.0) * f32(j) / 2.0 + f32(k)))
                i2 := int(math.floor(f32(j) * (f32(j) + 1.0) / 2.0 + f32(k)))
                v1: Vertex = {
                    pos = new_vs[i1].xyz,
                    uv = {new_vs[i1].w, new_vs[i1].w},
                    normal = la.normalize(new_vs[i1].xyz)
                }
                v2: Vertex = {
                    pos = new_vs[i2].xyz,
                    uv = {new_vs[i2].w, new_vs[i2].w},
                    normal = la.normalize(new_vs[i2].xyz)
                }
                v3: Vertex = {
                    pos = new_vs[i2 + 1].xyz,
                    uv = {new_vs[i2 + 1].w, new_vs[i2 + 1].w},
                    normal = la.normalize(new_vs[i2 + 1].xyz)
                }
                append(&vertices, v1, v2, v3)

                if k < (j - 1) {
                    i2 = i1 + 1
                    v2 = {
                        pos = new_vs[i2].xyz,
                        uv = {new_vs[i2].w, new_vs[i2].w},
                        normal = la.normalize(new_vs[i2].xyz)

                    }
                    append(&vertices, v1, v3, v2)
                }
            } 
        }
    }

    rs.player_fill_indices = make([]u32, len(vertices))
    rs.player_outline_indices = make([]u32, len(vertices) * 2)

    for i in 0..<len(vertices) {
        rs.player_fill_indices[i] = u32(i)
    }
    for i := 0; i < len(vertices); i += 3 {
        rs.player_outline_indices[i * 2] = u32(i)
        rs.player_outline_indices[i * 2 + 1] = u32(i + 1)
        rs.player_outline_indices[i * 2 + 2] = u32(i + 1)
        rs.player_outline_indices[i * 2 + 3] = u32(i + 2)
        rs.player_outline_indices[i * 2 + 4] = u32(i + 2)
        rs.player_outline_indices[i * 2 + 5] = u32(i)
    }

    rs.player_geometry.vertices = make([]Vertex, len(vertices))
    copy(rs.player_geometry.vertices, vertices[:])
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
            if j % 2 == 0 || i % 2 == 0 {
                v.pos.xyz = v.pos.xyz * 0.5
            // } else if i % 2 == 0{
            }
            uv: glm.vec2 = {f32(j) / f32(horizontal_count), f32(i) / f32(vertical_count)}
            v.uv = uv
            vertices[(horizontal_count + 1) * i + j] = v
        }
    }

    // ind := 0
    rs.player_outline_indices = make([]u32, SPHERE_I_COUNT * 2)
    rs.player_fill_indices = make([]u32, SPHERE_I_COUNT)
    fill_indices := &rs.player_fill_indices
    outline_indices := &rs.player_outline_indices
    outline_idx := 0
    fill_idx := 0
    for i in 0..<vertical_count {
        vr1 = u32(i * (horizontal_count + 1))
        vr2 = vr1 + u32(horizontal_count) + 1

        for j := 0; j < horizontal_count; {
            if i != 0 {
                fill_indices[fill_idx] = vr1
                fill_indices[fill_idx+1] = vr2
                fill_indices[fill_idx+2] = vr1+1
                fill_idx += 3
                outline_indices[outline_idx] = vr1
                outline_indices[outline_idx + 1] = vr1 + 1
                outline_idx += 2
            }
            if i != vertical_count - 1 {
                fill_indices[fill_idx] = vr1 + 1
                fill_indices[fill_idx+1] = vr2
                fill_indices[fill_idx+2] = vr2 + 1
                fill_idx += 3
            }
            outline_indices[outline_idx] = vr1
            outline_indices[outline_idx + 1] = vr2
            outline_idx += 2
            // if i != 0 {
            // }
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
        constrain_amt := 1.0 - easeout(clamp((time - constrain_start_t) / 300.0, 0.0, 1.0))
        if (time - ps.dash_time > 200) {
            constrain_amt = 1.0;
        }
        constrained_pos *= constrain_amt;
        constrained_pos += constrain_proj;
        constrained_pos += constrain_proj * (1.0 - constrain_amt) * 5.0 + ps.dash_dir * 5.0 * (1.0 - constrain_amt);
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


