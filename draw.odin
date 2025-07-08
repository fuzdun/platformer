package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import strcnv "core:strconv"
import la "core:math/linalg"

draw :: proc(
    lgs: Level_Geometry_State, 
    lrs: Level_Resources,
    pls: Player_State,
    rs: ^Render_State,
    shst: ^Shader_State,
    ps: ^Physics_State,
    cs: ^Camera_State,
    es: Editor_State,
    time: f64,
    interp_t: f64
) {
    clear_render_queues(rs)

    // add level geometry to command queues
    for g_off, idx in rs.render_group_offsets {
        next_off := idx == len(rs.render_group_offsets) - 1 ? u32(len(lgs.entities)) : rs.render_group_offsets[idx + 1]
        count := next_off - g_off
        if count == 0 do continue
        shader := ProgramName(idx / len(SHAPE))
        shape := SHAPE(idx % len(SHAPE))
        sd := lrs[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            count,
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
        proj_mat = construct_camera_matrix(cs)
    } else {
        proj_mat = interpolated_camera_matrix(cs, f32(interp_t))
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
        use_shader(shst, rs, .Trail)
        gl.BindVertexArray(rs.standard_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.Disable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
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

        

    // draw geometry connections in editor
    if EDIT && len(es.connections) > 0 {
        gl.BindVertexArray(rs.text_vao)
        use_shader(shst, rs, .Text)
        set_matrix_uniform(shst, "projection", &proj_mat)
        connection_vertices := make([dynamic]Line_Vertex); defer delete(connection_vertices)
        for el in es.connections {
            append(&connection_vertices, Line_Vertex{el.poss[0], 0}, Line_Vertex{el.poss[1], 1})
            avg_pos := el.poss[0] + (el.poss[1] - el.poss[0]) / 2
            dist_txt_buf: [3]byte            
            strcnv.itoa(dist_txt_buf[:], el.dist)
            scale := es.zoom / 400 * .02
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
