package main

import "core:fmt"
import "core:math"
import "core:slice"
import str "core:strings"
import TTF "vendor:sdl2/ttf"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"
import tm "core:time"
import strcnv "core:strconv"
import ft "shared:freetype"
import "core:os"
import st "state"
import enm "state/enums"

PLAYER_PARTICLE_STACK_COUNT :: 5
PLAYER_PARTICLE_SECTOR_COUNT :: 10

PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2
I_MAT :: glm.mat4(1.0)

//SHAPE :: enum{
//    CUBE,
//    WEIRD,
//}

SHAPE_FILENAME := [enm.SHAPE]string {
    .CUBE = "basic_cube",
    .WEIRD = "weird"
}

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

Vertex_Offsets :: [len(enm.SHAPE)]u32
Index_Offsets :: [len(enm.SHAPE)]u32

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

Renderable :: struct{
    transform: glm.mat4,
    z_width: f32
}

Shader_Render_Queues :: [enm.ProgramName][dynamic]gl.DrawElementsIndirectCommand

//init_render_buffers :: proc(gs: ^Game_State, rs: ^Render_State) {
//    for shader in ProgramName {
//        rs.shader_render_queues[shader] = make([dynamic]gl.DrawElementsIndirectCommand)
//    }
//    rs.static_transforms = make([dynamic]glm.mat4)
//    rs.z_widths = make([dynamic]f32)
//    rs.player_particle_poss = make([dynamic]glm.vec3)
//    add_player_sphere_data(gs)
//}

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

update_vertices :: proc(gs: ^st.Game_State, lrs: Level_Resources, rs: ^Render_State) {
    if len(gs.dirty_entities) > 0 {
        for lg_idx in gs.dirty_entities {
            lg := gs.level_geometry[lg_idx]
            trans_mat := trans_to_mat4(lg.transform)
            max_z := min(f32)
            min_z := max(f32)
            for v in lrs[lg.shape].vertices {
                new_pos := trans_mat * [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}
                max_z = max(new_pos.z, max_z)
                min_z = min(new_pos.z, min_z)
            }

            for offset, shader in lg.ssbo_indexes {
                if offset != -1 {
                    ssbo_idx := get_ssbo_idx(lg, shader, rs^)
                    if ssbo_idx > len(rs.static_transforms) - 1 {
                        append(&rs.static_transforms, trans_mat) 
                        append(&rs.z_widths, max_z - min_z)
                    } else {
                        rs.static_transforms[ssbo_idx] = trans_mat
                        rs.z_widths[ssbo_idx] = max_z - min_z
                    }
                }
            }
        }
    }
    clear(&gs.dirty_entities)
    //slice.sort_by(rs.static_transforms[:], proc(a: glm.mat4, b: glm.mat4) -> bool { return a[3][2] < b[3][2] })
}

update_player_particles :: proc(rs: ^Render_State, ps: st.Player_State, time: f32) {
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
        xz := SPHERE_RADIUS * math.cos(vertical_angle)
        y = SPHERE_RADIUS * math.sin(vertical_angle)
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
    top_pt: [4]f32 = {0, SPHERE_RADIUS * 2.0, 0, f32(end_idx)}
    bot_pt: [4]f32 = {0, -SPHERE_RADIUS * 2.0, 0, f32(end_idx + 1)}
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

render :: proc(
    gs: ^st.Game_State,
    lrs: Level_Resources,
    pls: st.Player_State,
    rs: ^Render_State,
    shst: ^Shader_State,
    ps: ^st.Physics_State,
    time: f64,
    interp_t: f64
) {
    clear_render_queues(rs)

    // add level geometry to command queues
    for g_off, idx in rs.render_group_offsets {
        next_off := idx == len(rs.render_group_offsets) - 1 ? u32(len(gs.level_geometry)) : rs.render_group_offsets[idx + 1]
        count := next_off - g_off
        if count == 0 do continue
        shader := enm.ProgramName(idx / len(enm.SHAPE))
        shape := enm.SHAPE(idx % len(enm.SHAPE))
        sd := lrs[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            next_off - g_off,
            rs.index_offsets[shape],
            rs.vertex_offsets[shape],
            g_off
        }
        append(&rs.shader_render_queues[shader], command)
    }

    // add player to command queue
    player_mat := interpolated_player_matrix(pls, f32(interp_t))
    player_rq := rs.shader_render_queues[.Player]
    //append(&player_rq.transforms, player_mat)
    append(&player_rq, gl.DrawElementsIndirectCommand{
        u32(len(rs.player_geometry.indices)),
        1,
        rs.player_index_offset,
        rs.player_vertex_offset,
        0
    })
    rs.shader_render_queues[.Player] = player_rq

    // execute draw queues
    proj_mat: glm.mat4
    if EDIT {
        proj_mat = construct_camera_matrix(&gs.camera_state)
    } else {
        proj_mat = interpolated_camera_matrix(&gs.camera_state, f32(interp_t))
    }

    if !EDIT {
        //gl.Disable(gl.DEPTH_TEST)
        //gl.Disable(gl.CULL_FACE)
        //bqv := BACKGROUND_VERTICES
        //gl.BindVertexArray(rs.background_vao)
        //use_shader(shst, rs, .Background)
        //set_float_uniform(shst, "i_time", f32(time) / 1000)
        //gl.BindBuffer(gl.ARRAY_BUFFER, rs.background_vbo)
        //gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        //gl.Enable(gl.DEPTH_TEST)
        //gl.Enable(gl.CULL_FACE)
    }

    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.static_transforms[0]) * len(rs.static_transforms), raw_data(rs.static_transforms), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.z_widths[0]) * len(rs.z_widths), raw_data(rs.z_widths), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)

    // if !EDIT && !gs.player_state.dashing {
    // }

    use_shader(shst, rs, .Simple)
    set_matrix_uniform(shst, "projection", &proj_mat)
    draw_shader_render_queue(rs, shst, gl.TRIANGLES)

    camera_right_worldspace: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
    camera_right_worldspace = la.normalize(camera_right_worldspace)
    camera_up_worldspace: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
    camera_up_worldspace = la.normalize(camera_up_worldspace)

    // draw player
    if !EDIT {
        // if !gs.player_state.dashing {
            use_shader(shst, rs, .Player)
            // p_color: [3]f32 = gs.player_state.dashing ? {0.0, 1.0, 0} : {0.9, 0.3, 0.9}
            p_color := [3]f32 {1.0, 0.0, 0.0}
            constrain_len: f32 = 250.0
            constrain_dir := la.normalize0(pls.dash_dir)
            set_matrix_uniform(shst, "projection", &proj_mat)
            set_matrix_uniform(shst, "transform", &player_mat)
            set_float_uniform(shst, "i_time", f32(time))
            set_float_uniform(shst, "dash_time", pls.dash_time)
            set_float_uniform(shst, "dash_end_time", pls.dash_end_time)
            set_vec3_uniform(shst, "p_color", 1, &p_color)
            set_vec3_uniform(shst, "constrain_dir", 1, &constrain_dir)
            draw_shader_render_queue(rs, shst, gl.TRIANGLES)

            use_shader(shst, rs, .Player_Particle)
            gl.Enable(gl.BLEND)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
            gl.BindVertexArray(rs.particle_vao)
            pv := PARTICLE_VERTICES
            for &pv in pv {
                pv.position = camera_right_worldspace * pv.position.x + camera_up_worldspace * pv.position.y
            }
            pp := rs.player_particles
            i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))
            set_matrix_uniform(shst, "projection", &proj_mat)
            set_float_uniform(shst, "i_time", f32(time))
            set_float_uniform(shst, "radius", 3.0)
            set_vec3_uniform(shst, "player_pos", 1, &i_ppos)
            set_vec3_uniform(shst, "constrain_dir", 1, &constrain_dir)
            set_float_uniform(shst, "dash_time", pls.dash_time)
            set_float_uniform(shst, "dash_end_time", pls.dash_end_time)
            gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(pv[0]) * len(pv), &pv[0], gl.DYNAMIC_DRAW) 
            gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(pp[0]) * len(pp), &pp[0], gl.DYNAMIC_DRAW) 
            gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, PLAYER_PARTICLE_COUNT)
            gl.Disable(gl.BLEND)
        // }
        // else {
            gl.BindVertexArray(rs.lines_vao)
            use_shader(shst, rs, .Line)
            dash_dir := pls.dash_dir
            set_vec3_uniform(shst, "dash_dir", 1, &dash_dir)
            set_matrix_uniform(shst, "projection", &proj_mat)
            set_float_uniform(shst, "i_time", f32(time))
            set_float_uniform(shst, "dash_time", pls.dash_time)
            set_float_uniform(shst, "resolution", f32(20))
            dash_line_start := pls.dash_start_pos + pls.dash_dir * 4.5;
            dash_line: [2]Line_Vertex = {{dash_line_start, 0}, {pls.dash_end_pos, 1}}
            green := [3]f32{1.0, 1.0, 0.0}
            set_vec3_uniform(shst, "color", 1, &green)
            gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.DYNAMIC_DRAW)
            gl.LineWidth(2)
            gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))
        // }
    }

    //fmt.println("===")
    if EDIT {
        use_shader(shst, rs, .Trail)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_shader_render_queue(rs, shst, gl.TRIANGLES)
    } else {
        gl.BindVertexArray(rs.standard_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.Disable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        use_shader(shst, rs, .Trail)
        crunch_pt : glm.vec3 = pls.crunch_pt
        player_pos := pls.position
        player_trail := interpolated_trail(pls, f32(interp_t))
        set_vec3_uniform(shst, "player_trail", 3, &player_trail[0])
        set_vec3_uniform(shst, "player_pos", 1, &player_pos)
        set_vec3_uniform(shst, "crunch_pt", 1, &crunch_pt)
        set_float_uniform(shst, "crunch_time", f32(pls.crunch_time) / 1000)
        set_float_uniform(shst, "time", f32(time) / 1000)
        set_matrix_uniform(shst, "projection", &proj_mat)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        draw_shader_render_queue(rs, shst, gl.PATCHES)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    }

        

    // draw geometry connections in editor
    if EDIT && len(gs.editor_state.connections) > 0 {
        gl.BindVertexArray(rs.text_vao)
        use_shader(shst, rs, .Text)
        set_matrix_uniform(shst, "projection", &proj_mat)
        connection_vertices := make([dynamic]Line_Vertex); defer delete(connection_vertices)
        for el in gs.editor_state.connections {
            append(&connection_vertices, Line_Vertex{el.poss[0], 0}, Line_Vertex{el.poss[1], 1})
            avg_pos := el.poss[0] + (el.poss[1] - el.poss[0]) / 2
            dist_txt_buf: [3]byte            
            strcnv.itoa(dist_txt_buf[:], el.dist)
            scale := gs.editor_state.zoom / 400 * .02
            render_text(shst, rs, string(dist_txt_buf[:]), avg_pos, camera_up_worldspace, camera_right_worldspace, scale)
        }

        gl.BindVertexArray(rs.lines_vao)
        use_shader(shst, rs, .Outline)
        set_matrix_uniform(shst, "projection", &proj_mat)
        red := [3]f32{1.0, 0.0, 0.0}
        set_vec3_uniform(shst, "color", 1, &red)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(connection_vertices[0]) * len(connection_vertices), &connection_vertices[0], gl.DYNAMIC_DRAW)
        gl.DrawArrays(gl.LINES, 0, i32(len(connection_vertices)))
    }
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

draw_shader_render_queue :: proc(rs: ^Render_State, shst: ^Shader_State, mode: u32) {
    queue := rs.shader_render_queues[shst.loaded_program_name]
    //fmt.println(queue)
    if len(queue) > 0 {
        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, rs.indirect_buffer)
        gl.BufferData(gl.DRAW_INDIRECT_BUFFER, size_of(queue[0]) * len(queue), raw_data(queue), gl.DYNAMIC_DRAW)
        gl.MultiDrawElementsIndirect(mode, gl.UNSIGNED_INT, nil, i32(len(queue)), 0)
    }
}

