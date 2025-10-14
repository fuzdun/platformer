package main

import "core:sort"
import "core:fmt"
import "core:slice"
import "core:math"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import tim "core:time"

draw :: proc(
    lgs: #soa[]Level_Geometry, 
    //sorted_lgs: #soa[]Level_Geometry,
    sr: Shape_Resources,
    pls: Player_State,
    rs: ^Render_State,
    shs: ^Shader_State,
    ps: ^Physics_State,
    cs: ^Camera_State,
    is: Input_State,
    es: Editor_State,
    szs: Slide_Zone_State,
    time: f64,
    interp_t: f64
) {
    // =====================
    //  PREPARE RENDER DATA
    // =====================
    group_offsets: [NUM_RENDER_GROUPS]int
    
    culled_lgs := make(#soa[dynamic]Level_Geometry)
    defer delete(culled_lgs)
    reserve_soa(&culled_lgs, len(lgs))
    
    for lg, idx in lgs {
        if true {
            append(&culled_lgs, lg)
            group_offsets[lg_render_group(lg)] += 1
        }
    }

    num_culled_lgs := len(culled_lgs)

    counts_to_offsets(group_offsets[:])
    draw_commands := offsets_to_render_commands(group_offsets[:], len(culled_lgs), rs^, sr)
    defer free_render_groups(draw_commands)

    z_widths := make([]f32, num_culled_lgs); defer delete(z_widths)
    for i in 0..<num_culled_lgs {
        z_widths[i] = 20
    }

    transforms, angular_velocities,
    shapes, colliders, render_types,
    attributess, aabbs, crack_times,
    break_datas, transparencies := soa_unzip(culled_lgs[:])

    transform_mats := make([]glm.mat4, num_culled_lgs); defer delete(transform_mats)
    for t, i in transforms {
        transform_mats[i] = trans_to_mat4(t)
    }

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(glm.mat4) * num_culled_lgs, &transform_mats[0])

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(f32) * num_culled_lgs, &z_widths[0])

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.crack_time_ssbo)
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(f32) * num_culled_lgs, &crack_times[0])

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.break_data_ssbo)
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(Break_Data) * num_culled_lgs, &break_datas[0])

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transparencies_ssbo)
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, size_of(f32) * num_culled_lgs, &transparencies[0])

    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, rs.crack_time_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, rs.break_data_ssbo)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 4, rs.transparencies_ssbo)

    // get projection matrix
    proj_mat := EDIT ? construct_camera_matrix(cs^) : interpolated_camera_matrix(cs, f32(interp_t))

    // load shared uniform data into UBOs
    common_ubo: Common_Ubo = {
        projection = proj_mat,
        time = f32(time)
    }
    dash_ubo : Dash_Ubo = {
        dash_time = pls.dash_state.dash_time,
        dash_total = pls.dash_state.dash_total,
        constrain_dir = la.normalize0(pls.dash_state.dash_dir)
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

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.transforms_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.mat4) * num_culled_lgs, &transform_mats[0])

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
        draw_editor(rs, shs, es, is, lgs, draw_commands, proj_mat)

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

        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        // draw level geometry
        gl.BindVertexArray(rs.standard_vao)
        use_shader(shs, rs, .Level_Geometry_Fill)
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
        slide_middle := SLIDE_LEN / 2.0
        slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
        start_slide_t := clamp(pls.slide_state.slide_total / slide_middle, 0, 1) * 0.5
        end_slide_t := clamp(((pls.slide_state.slide_total - slide_off) - (slide_middle)) / slide_middle, 0, 1) * 0.5
        slide_t := start_slide_t + end_slide_t
        set_float_uniform(shs, "slide_t", slide_t)
        draw_indirect_render_queue(rs^, draw_commands[.Standard][:], gl.PATCHES)

        gl.BindVertexArray(rs.standard_vao)
        use_shader(shs, rs, .Bouncy)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time) / 1000)
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_float_uniform(shs, "slide_t", slide_t)
        draw_indirect_render_queue(rs^, draw_commands[.Bouncy][:], gl.PATCHES)

        use_shader(shs, rs, .Wireframe)
        gl.Enable(gl.BLEND)
        wireframe_color := [3]f32{0.000, 0.300, 0.600}
        set_vec3_uniform(shs, "color", 1, &wireframe_color)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(rs^, draw_commands[.Wireframe][:], gl.LINES)
        gl.Disable(gl.BLEND)


        use_shader(shs, rs, .Barrier)
        gl.Enable(gl.BLEND)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(rs^, draw_commands[.Dash_Barrier][:], gl.PATCHES)
        gl.Disable(gl.BLEND)

        // draw background
        gl.Enable(gl.BLEND)
        gl.Disable(gl.DEPTH_TEST)
        use_shader(shs, rs, .Background)
        if len(pls.crunch_pts) > 0 {
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
        outline_color := [3]f32{0.75, 0.75, 0.75}
        set_vec3_uniform(shs, "color", 1, &outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Standard][:], gl.PATCHES)
        barrier_outline_color := [3]f32{1.0, 0, 0}
        set_vec3_uniform(shs, "color", 1, &barrier_outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Dash_Barrier][:], gl.PATCHES)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        // draw player -- see player draw func below
        draw_player(rs, pls, shs, f32(time), f32(interp_t))

        gl.Enable(gl.BLEND)
        gl.BindVertexArray(rs.standard_vao)
        use_shader(shs, rs, .Slide_Zone)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(rs^, draw_commands[.Slide_Zone][:], gl.TRIANGLES)
        gl.Disable(gl.BLEND)

        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)
        use_shader(shs, rs, .Level_Geometry_Outline)
        slide_zone_outline_color := [3]f32{0, 0, 1.0}
        set_vec3_uniform(shs, "color", 1, &slide_zone_outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Slide_Zone][:], gl.PATCHES)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)


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
