package main

import "core:sort"
import "core:fmt"
import "core:slice"
import "core:math"
import rand "core:math/rand"
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
            z_width =  30, // need to change this
        }
    }

    counts_to_offsets(group_offsets[:])

    // generate command queues
    for g_off, idx in group_offsets {
        next_off := idx == len(group_offsets) - 1 ? len(sorted_transforms) : group_offsets[idx + 1]
        count := u32(next_off - g_off)
        if count == 0 do continue
        shape := SHAPE(idx % len(SHAPE))
        render_type := Level_Geometry_Render_Type(math.floor(f32(idx) / f32(len(Level_Geometry_Render_Type))))
        sd := sr[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            count,
            rs.index_offsets[shape],
            rs.vertex_offsets[shape],
            u32(g_off)
        }
        append(&lg_render_groups[render_type], command)
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

    // load data into UBOs
    common_ubo: Common_Ubo = {
        projection = proj_mat,
        time = f32(time)
    }
    dash_ubo : Dash_Ubo = {
        dash_time = pls.dash_time,
        dash_end_time = pls.dash_end_time,
        constrain_dir = la.normalize0(pls.dash_dir)
    }
    i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.common_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Common_Ubo), &common_ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.dash_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Dash_Ubo), &dash_ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.ppos_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.vec3), &i_ppos[0])

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
    } else if PLAYER_DRAW {
        // draw player
        gl.Viewport(0, 0, WIDTH, HEIGHT)

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.BindVertexArray(rs.player_vao)
        offset_vertices := make([]Vertex, len(rs.player_geometry.vertices)); defer delete(offset_vertices)
        copy(offset_vertices, rs.player_geometry.vertices[:])
        displacement_dir := la.normalize0(pls.particle_displacement)

        down_rad := math.atan2_f32(-1.0, 2.0)
        rot_mat := la.matrix4_rotate_f32(f32(time) / 100, la.cross([3]f32{0, 1, 0}, la.normalize(pls.velocity)))
        for &v, idx in offset_vertices {
            rand.reset(u64(idx))
            v.pos = la.matrix_mul_vector(rot_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}).xyz
            if v.uv.x != 1.0 {
                v.pos *= f32(pls.spike_compression)
            } else {
                v_rad := math.atan2(v.pos.y, v.pos.z)
                v.pos *= min(2, max(1, 2 - 0.75 * abs(down_rad - v_rad)))
                v.pos *= 1.2
            }

            if pls.state == .ON_GROUND {
            }

            displacement_fact := la.dot(displacement_dir, la.normalize0(v.pos))
            if displacement_fact > 0.25 {
                displacement_fact *= 0.5
            }
            v.pos = la.clamp_length(v.pos + pls.particle_displacement * displacement_fact * 0.030, 3.0)
            v.pos += pls.particle_displacement * displacement_fact * 0.030
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, rs.player_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(offset_vertices[0]) * len(offset_vertices), raw_data(offset_vertices), gl.STATIC_DRAW) 
        p_color := [3]f32 {1.0, 0.0, 0.0}
        player_mat := interpolated_player_matrix(pls, f32(interp_t))

        gl.Disable(gl.CULL_FACE)
        //
        use_shader(shst, rs, .Player_Fill)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        set_matrix_uniform(shst, "transform", &player_mat)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_fill_ebo)
        gl.DrawElements(gl.TRIANGLES, i32(len(rs.player_fill_indices)), gl.UNSIGNED_INT, nil)

         //gl.Disable(gl.DEPTH_TEST)
        use_shader(shst, rs, .Player_Outline)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        set_matrix_uniform(shst, "transform", &player_mat)
        gl.LineWidth(1)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        gl.DrawElements(gl.LINES, i32(len(rs.player_outline_indices)), gl.UNSIGNED_INT, nil)

        gl.Enable(gl.CULL_FACE)
        // gl.Enable(gl.DEPTH_TEST)

        //draw player particles
        // use_shader(shst, rs, .Player_Particle)
        // gl.BindVertexArray(rs.particle_vao)
        // set_float_uniform(shst, "radius", 3.0)
        // pv := PARTICLE_VERTICES
        // for &pv in pv {
        //     pv.position = camera_right_worldspace * pv.position.x + camera_up_worldspace * pv.position.y
        // }
        // pp := rs.player_particles
        // gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
        // gl.BufferData(gl.ARRAY_BUFFER, size_of(pv[0]) * len(pv), &pv[0], gl.STATIC_DRAW) 
        // gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
        // gl.BufferData(gl.ARRAY_BUFFER, size_of(pp[0]) * len(pp), &pp[0], gl.STATIC_DRAW) 
        // gl.Enable(gl.BLEND)
        // gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        // gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, PLAYER_PARTICLE_COUNT)
        // gl.Disable(gl.BLEND)

    } else {
        gl.Viewport(0, 0, WIDTH, HEIGHT)

        gl.BindFramebuffer(gl.FRAMEBUFFER, rs.postprocessing_fbo)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Enable(gl.DEPTH_TEST)

        // draw background 
        use_shader(shst, rs, .Background)
        gl.BindVertexArray(rs.background_vao)
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)


        // draw level geometry
        use_shader(shst, rs, .Level_Geometry_Fill)
        gl.BindVertexArray(rs.standard_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        crunch_pt : glm.vec3 = pls.crunch_pt
        set_vec3_uniform(shst, "crunch_pt", 1, &crunch_pt)
        player_trail := interpolated_trail(pls, f32(interp_t))
        set_vec3_uniform(shst, "player_trail", 3, &player_trail[0])
        set_float_uniform(shst, "crunch_time", f32(pls.crunch_time) / 1000)
        inverse_view := glm.inverse(only_view_matrix(cs, f32(interp_t)))
        set_matrix_uniform(shst, "inverse_view", &inverse_view)
        inverse_proj := glm.inverse(only_projection_matrix(cs, f32(interp_t)))
        set_matrix_uniform(shst, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shst, "camera_pos", 1, &cs.position)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.PATCHES)

        // draw level geometry outline
        use_shader(shst, rs, .Level_Geometry_Outline)
        gl.BindVertexArray(rs.standard_vao)
        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.TRIANGLES)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        // draw player
        gl.BindVertexArray(rs.player_vao)
        offset_vertices := make([]Vertex, len(rs.player_geometry.vertices)); defer delete(offset_vertices)
        copy(offset_vertices, rs.player_geometry.vertices[:])
        displacement_dir := la.normalize0(pls.particle_displacement)

        rot_mat := la.matrix4_rotate_f32(f32(time) / 100, la.cross([3]f32{0, 1, 0}, la.normalize(pls.velocity)))
        stretch_dir := la.normalize(-la.normalize(pls.velocity) - {0, 0.5, 0})
        right_vec := la.cross([3]f32{0, 1, 0}, la.normalize(pls.velocity))
        //stretch_dir := -la.normalize(pls.velocity) - {0, 0.5, 0}
        for &v, idx in offset_vertices {
            rand.reset(u64(idx))
            v.pos = la.matrix_mul_vector(rot_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}).xyz
            if v.uv.x != 1.0 {
                v.pos *= f32(pls.spike_compression)
            } else if pls.state == .ON_GROUND {
                //v_rad := math.atan2(v.pos.y, v.pos.z)
                //diff := abs(down_rad - v_rad)
                //fmt.println(diff)
                //if diff > math.PI {
                //    diff = math.PI * 2 - diff
                //}
                norm_pos := la.normalize(v.pos - (la.dot(v.pos, right_vec) * right_vec * 0.5))
                down_alignment := max(0.25, min(0.75, la.dot(norm_pos, [3]f32{0, -1, 0})))
                down_alignment = (down_alignment - 0.25) / 0.5

                stretch_alignment := max(0.5, min(1.0, la.dot(norm_pos, stretch_dir)))
                stretch_alignment = (stretch_alignment - 0.5) / 0.5
                stretch_amt := stretch_alignment * stretch_alignment * stretch_alignment * la.length(pls.velocity) / 40.0

                v.pos *= (1.0 - down_alignment * 0.5)
                v.pos *= 1 + stretch_amt
                v.pos *= 1.2
            }

            if pls.state == .ON_GROUND {
            }

            displacement_fact := la.dot(displacement_dir, la.normalize0(v.pos))
            if displacement_fact > 0.25 {
                displacement_fact *= 0.5
            }
            v.pos = la.clamp_length(v.pos + pls.particle_displacement * displacement_fact * 0.030, 3.0)
            v.pos += pls.particle_displacement * displacement_fact * 0.030
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, rs.player_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(offset_vertices[0]) * len(offset_vertices), raw_data(offset_vertices), gl.STATIC_DRAW) 
        p_color := [3]f32 {1.0, 0.0, 0.0}
        player_mat := interpolated_player_matrix(pls, f32(interp_t))

        gl.Disable(gl.CULL_FACE)
        //
        use_shader(shst, rs, .Player_Fill)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        set_matrix_uniform(shst, "transform", &player_mat)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_fill_ebo)
        gl.DrawElements(gl.TRIANGLES, i32(len(rs.player_fill_indices)), gl.UNSIGNED_INT, nil)

         //gl.Disable(gl.DEPTH_TEST)
        use_shader(shst, rs, .Player_Outline)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        set_matrix_uniform(shst, "transform", &player_mat)
        gl.LineWidth(0.25)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        gl.DrawElements(gl.LINES, i32(len(rs.player_outline_indices)), gl.UNSIGNED_INT, nil)

        gl.Enable(gl.CULL_FACE)
        // gl.Enable(gl.DEPTH_TEST)

        // draw player dash trail
        use_shader(shst, rs, .Dash_Line)
        gl.BindVertexArray(rs.lines_vao)
        green := [3]f32{1.0, 0.0, 1.0}
        set_vec3_uniform(shst, "color", 1, &green)
        set_float_uniform(shst, "resolution", f32(20))
        dash_line_start := pls.dash_start_pos + pls.dash_dir * 4.5;
        dash_line: [2]Line_Vertex = {{dash_line_start, 0}, {pls.dash_end_pos, 1}}
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.DYNAMIC_DRAW)
        gl.LineWidth(2)
        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))
        gl.Disable(gl.BLEND)

        //draw player particles
        // use_shader(shst, rs, .Player_Particle)
        // gl.BindVertexArray(rs.particle_vao)
        // set_float_uniform(shst, "radius", 3.0)
        // pv := PARTICLE_VERTICES
        // for &pv in pv {
        //     pv.position = camera_right_worldspace * pv.position.x + camera_up_worldspace * pv.position.y
        // }
        // pp := rs.player_particles
        // gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
        // gl.BufferData(gl.ARRAY_BUFFER, size_of(pv[0]) * len(pv), &pv[0], gl.STATIC_DRAW) 
        // gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
        // gl.BufferData(gl.ARRAY_BUFFER, size_of(pp[0]) * len(pp), &pp[0], gl.STATIC_DRAW) 
        // gl.Enable(gl.BLEND)
        // gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        // gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, PLAYER_PARTICLE_COUNT)
        // gl.Disable(gl.BLEND)

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0) 
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        use_shader(shst, rs, .Postprocessing)

        //proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{pls.crunch_pt.x, pls.crunch_pt.y, pls.crunch_pt.z, 1})
        //proj_ppos /= proj_ppos.w
        //proj_ppos2 := proj_ppos.xy / 2.0 + 0.5
        screen_crunch_pt := pls.screen_crunch_pt

        set_float_uniform(shst, "time", f32(time))
        set_float_uniform(shst, "crunch_time", f32(pls.crunch_time))
        set_vec2_uniform(shst, "ppos", 1, &screen_crunch_pt)
        gl.BindVertexArray(rs.background_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.postprocessing_tcb)
        gl.Disable(gl.DEPTH_TEST)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
}

