package main

import "core:sort"
import "core:fmt"
import "core:slice"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import strcnv "core:strconv"
import la "core:math/linalg"

draw :: proc(
    lgs: ^Level_Geometry_State, 
    sr: Shape_Resources,
    pls: Player_State,
    rs: ^Render_State,
    shst: ^Shader_State,
    ps: ^Physics_State,
    cs: ^Camera_State,
    es: Editor_State,
    time: f64,
    interp_t: f64
) {
    // init level geometry render queues
    lg_render_groups: [Level_Geometry_Render_Type][dynamic]gl.DrawElementsIndirectCommand 

    for &rg in lg_render_groups {
        rg = make([dynamic]gl.DrawElementsIndirectCommand)
    }; defer for &rg in lg_render_groups { delete(rg) }

    lg_count := len(lgs.entities)

    sorted_rd          := make([]Lg_Render_Data, lg_count);                 defer delete(sorted_rd)
    sorted_transforms  := make([]glm.mat4, lg_count);                       defer delete(sorted_transforms)
    sorted_z_widths    := make([]f32, lg_count);                            defer delete(sorted_z_widths)
    lg_render_commands := make([]gl.DrawElementsIndirectCommand, lg_count); defer delete(lg_render_commands) 

    // sort level geometry by shader and shape
    group_offsets: [len(SHAPE) * len(Level_Geometry_Render_Type)]int
    for lg, idx in lgs.entities {
        render_group := int(lg.render_type) * len(SHAPE) + int(lg.shape)
        group_offsets[render_group] += 1
        sorted_rd[idx] = Lg_Render_Data {
            render_group = render_group,
            transform_mat = trans_to_mat4(lg.transform),
            z_width = 10, // need to change this
        }
    }

    counts_to_offsets(group_offsets[:])

    // generate command queues
    for g_off, idx in group_offsets {
        next_off := idx == len(group_offsets) - 1 ? len(sorted_transforms) : group_offsets[idx + 1]
        count := u32(next_off - g_off)
        if count == 0 do continue
        shape := SHAPE(idx % len(SHAPE))
        sd := sr[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            count,
            rs.index_offsets[shape],
            rs.vertex_offsets[shape],
            u32(g_off)
        }
        append(&lg_render_groups[.Standard], command)
    }

    // sort and distribute level geometry transforms and z_widths 
    slice.sort_by(sorted_rd[:], proc(a: Lg_Render_Data, b: Lg_Render_Data) -> bool { return a.render_group < b.render_group })
    for rd, idx in sorted_rd {
        sorted_transforms[idx] = rd.transform_mat
        sorted_z_widths[idx] = rd.z_width
    }

    // load sorted matrices and z_widths into SSBOs
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(sorted_transforms[0]) * len(sorted_transforms), raw_data(sorted_transforms), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(sorted_z_widths[0]) * len(sorted_z_widths), raw_data(sorted_z_widths), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)

    // get projection matrix
    proj_mat := EDIT ? construct_camera_matrix(cs) : interpolated_camera_matrix(cs, f32(interp_t))

    // get axes for text and particle quad alignment
    camera_right_worldspace: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
    camera_right_worldspace = la.normalize(camera_right_worldspace)
    camera_up_worldspace: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
    camera_up_worldspace = la.normalize(camera_up_worldspace)

    if EDIT {
        // draw level geometry (edit mode)
        use_shader(shst, rs, .Editor_Geometry)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.TRIANGLES)

        // draw geometry connections
        if len(es.connections) > 0 {
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
            use_shader(shst, rs, .Connection_Line)
            set_matrix_uniform(shst, "projection", &proj_mat)
            red := [3]f32{1.0, 0.0, 0.0}
            set_vec3_uniform(shst, "color", 1, &red)
            gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(connection_vertices[0]) * len(connection_vertices), &connection_vertices[0], gl.DYNAMIC_DRAW)
            gl.DrawArrays(gl.LINES, 0, i32(len(connection_vertices)))
        }

    } else {

        // draw background 
        use_shader(shst, rs, .Background)
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        set_float_uniform(shst, "i_time", f32(time) / 1000)
        gl.BindVertexArray(rs.background_vao)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)

        // draw level geometry outline
        use_shader(shst, rs, .Level_Geometry_Outline)
        gl.BindVertexArray(rs.standard_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.TRIANGLES)

        // draw player
        use_shader(shst, rs, .Player)
        p_color := [3]f32 {1.0, 0.0, 0.0}
        constrain_len: f32 = 250.0
        constrain_dir := la.normalize0(pls.dash_dir)
        player_mat := interpolated_player_matrix(pls, f32(interp_t))
        set_matrix_uniform(shst, "projection", &proj_mat)
        set_matrix_uniform(shst, "transform", &player_mat)
        set_float_uniform(shst, "i_time", f32(time))
        set_float_uniform(shst, "dash_time", pls.dash_time)
        set_float_uniform(shst, "dash_end_time", pls.dash_end_time)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        set_vec3_uniform(shst, "constrain_dir", 1, &constrain_dir)
        draw_indirect_render_queue(rs^, rs.player_draw_command[:], gl.TRIANGLES)

        //draw player particles
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

        // draw player dash trail
        gl.BindVertexArray(rs.lines_vao)
        use_shader(shst, rs, .Dash_Line)
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
        
        // draw level geometry
        use_shader(shst, rs, .Level_Geometry_Fill)
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
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.PATCHES)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    }
}

