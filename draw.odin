package main

import "core:fmt"
import "core:slice"
import "core:math"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"

draw :: proc(
    lgs: ^Level_Geometry_State, 
    sr: Shape_Resources,
    pls: Player_State,
    rs: ^Render_State,
    shs: ^Shader_State,
    ps: ^Physics_State,
    cs: ^Camera_State,
    es: Editor_State,
    time: f64,
    interp_t: f64
) {
    // =====================
    //  PREPARE RENDER DATA
    // =====================

    // init level geometry render queues
    lg_render_groups: Render_Groups 

    for &rg in lg_render_groups {
        rg = make([dynamic]gl.DrawElementsIndirectCommand)
    }; defer for &rg in lg_render_groups { delete(rg) }

    lg_count := len(lgs.entities)

    sorted_rd          := make([]Lg_Render_Data, lg_count);                 defer delete(sorted_rd)
    sorted_transforms  := make([]glm.mat4, lg_count);                       defer delete(sorted_transforms)
    sorted_z_widths    := make([]f32, lg_count);                            defer delete(sorted_z_widths)
    sorted_crack_times := make([]f32, lg_count);                            defer delete(sorted_crack_times)
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
            crack_time = lg.crack_time
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

    // sort and distribute level geometry attributes 
    slice.sort_by(sorted_rd[:], proc(a: Lg_Render_Data, b: Lg_Render_Data) -> bool { return a.render_group < b.render_group })
    for rd, idx in sorted_rd {
        sorted_transforms[idx] = rd.transform_mat
        sorted_z_widths[idx] = rd.z_width
        sorted_crack_times[idx] = rd.crack_time
    }

    // load level geometry attributes into buffers
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(sorted_transforms[0]) * len(sorted_transforms), raw_data(sorted_transforms), gl.DYNAMIC_DRAW)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(sorted_z_widths[0]) * len(sorted_z_widths), raw_data(sorted_z_widths), gl.DYNAMIC_DRAW)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.crack_time_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(sorted_crack_times[0]) * len(sorted_crack_times), raw_data(sorted_crack_times), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, rs.crack_time_ssbo)

    // get projection matrix
    proj_mat := EDIT ? construct_camera_matrix(cs) : interpolated_camera_matrix(cs, f32(interp_t))

    // load shared uniform data into UBOs
    common_ubo: Common_Ubo = {
        projection = proj_mat,
        time = f32(time)
    }
    dash_ubo : Dash_Ubo = {
        dash_time = pls.dash_time,
        dash_end_time = pls.dash_end_time,
        constrain_dir = la.normalize0(pls.dash_dir)
    }
    tess_ubo : Tess_Ubo = {
        inner_amt = INNER_TESSELLATION_AMT,
        outer_amt = OUTER_TESSELLATION_AMT
    }
    i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.common_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Common_Ubo), &common_ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.dash_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Dash_Ubo), &dash_ubo)
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.ppos_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.vec3), &i_ppos[0])
    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.tess_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Tess_Ubo), &tess_ubo)

    // get axes for text and particle quad alignment
    camera_right_worldspace: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
    camera_right_worldspace = la.normalize(camera_right_worldspace)
    camera_up_worldspace: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
    camera_up_worldspace = la.normalize(camera_up_worldspace)

    // ====================
    //  EXECUTE DRAW CALLS
    // ====================

    gl.Viewport(0, 0, WIDTH, HEIGHT)

    if EDIT {
        // draw edit mode UI/level geometry
        draw_editor(rs, shs, es, lg_render_groups, proj_mat)

    } else if PLAYER_DRAW {
        // -- see player draw func below
        draw_player(rs, pls, shs, f32(time), f32(interp_t))
      
    } else {
        // bind intermediate framebuffer
        gl.BindFramebuffer(gl.FRAMEBUFFER, rs.postprocessing_fbo)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)

        // draw background 
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        // draw level geometry
        use_shader(shs, rs, .Level_Geometry_Fill)
        gl.BindVertexArray(rs.standard_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        crunch_pt : glm.vec3 = pls.crunch_pt
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        player_trail := interpolated_trail(pls, f32(interp_t))
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time) / 1000)
        inverse_view := glm.inverse(only_view_matrix(cs, f32(interp_t)))
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        inverse_proj := glm.inverse(only_projection_matrix(cs, f32(interp_t)))
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.PATCHES)

        // draw background
        gl.Enable(gl.BLEND)
        gl.Disable(gl.DEPTH_TEST)
        use_shader(shs, rs, .Background)
        if len(pls.crunch_pts) > 0 {
            // fmt.println(pls.crunch_pts)
            cpts := pls.crunch_pts[:]
            set_vec4_uniform(shs, "crunch_pts", i32(len(pls.crunch_pts)), &cpts[0])
        }
        set_int_uniform(shs, "crunch_pt_count", i32(len(pls.crunch_pts)))
        gl.BindVertexArray(rs.background_vao)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        gl.Disable(gl.BLEND)
        gl.Enable(gl.DEPTH_TEST)

        // draw level geometry outline
        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)
        use_shader(shs, rs, .Level_Geometry_Outline)
        gl.BindVertexArray(rs.standard_vao)
        draw_indirect_render_queue(rs^, lg_render_groups[.Standard][:], gl.PATCHES)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        // draw player -- see player draw func below
        draw_player(rs, pls, shs, f32(time), f32(interp_t))

        // draw to main framebuffer with postprocessing effects
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0) 
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        use_shader(shs, rs, .Postprocessing)
        screen_crunch_pt := pls.screen_crunch_pt
        set_float_uniform(shs, "time", f32(time))
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time))
        set_vec2_uniform(shs, "ppos", 1, &screen_crunch_pt)
        gl.BindVertexArray(rs.background_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.postprocessing_tcb)
        gl.Disable(gl.DEPTH_TEST)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
}
