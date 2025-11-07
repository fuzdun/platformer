package main

import "core:sort"
import "core:fmt"
import "core:slice"
import "core:math"
import vmem "core:mem/virtual"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import tim "core:time"

FWD_Z_CULL :: 600
BCK_Z_CULL :: 100

draw :: proc(
    lgs: #soa[]Level_Geometry, 
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

    // #####################################################
    //  PREPARE RENDER DATA
    // #####################################################

    // count geometry groups and cull 
    // -------------------------------------------
    group_offsets: [NUM_RENDER_GROUPS]int
    culled_lgs := make(#soa[dynamic]Level_Geometry, context.temp_allocator)
    reserve_soa(&culled_lgs, len(lgs))
    min_z_cull := cs.position.z - FWD_Z_CULL
    max_z_cull := cs.position.z + BCK_Z_CULL
    for lg, idx in lgs {
        if EDIT || (lg.transform.position.z < max_z_cull && lg.transform.position.z > min_z_cull) {
            append(&culled_lgs, lg)
            group_offsets[lg_render_group(lg)] += 1
        }
    }
    num_culled_lgs := len(culled_lgs)

    // generate draw commands 
    // -------------------------------------------
    counts_to_offsets(group_offsets[:])
    draw_commands := offsets_to_render_commands(group_offsets[:], len(culled_lgs), rs^, sr)

    // load UBOs 
    // -------------------------------------------
    transforms, angular_velocities,
    shapes, colliders, render_types,
    attributess, aabbs, shatter_datas,
    transparencies, _physics_idx := soa_unzip(culled_lgs[:])

    proj_mat := EDIT ? construct_camera_matrix(cs^) : interpolated_camera_matrix(cs, f32(interp_t))
    i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))

    z_widths := make([]Z_Width_Ubo, num_culled_lgs, context.temp_allocator)
    for i in 0..<num_culled_lgs {
        z_widths[i] = { 20 }
    }

    transparency_ubos := make([]Transparency_Ubo, num_culled_lgs, context.temp_allocator)
    for t, i in transparencies {
        transparency_ubos[i] = { t }
    }

    transform_mats := make([]glm.mat4, num_culled_lgs, context.temp_allocator)
    for t, i in transforms {
        transform_mats[i] = trans_to_mat4(t)
    }

    common_ubo: Common_Ubo = {
        projection = proj_mat,
        time = f32(time)
    }

    dash_ubo : Dash_Ubo = {
        dash_time = pls.dash_state.dash_time,
        dash_total = f32(time) - pls.dash_state.dash_time,
        constrain_dir = la.normalize0(pls.dash_state.dash_dir)
    }

    tess_ubo : Tess_Ubo = {
        inner_amt = INNER_TESSELLATION_AMT,
        outer_amt = OUTER_TESSELLATION_AMT
    }

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

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.z_widths_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.vec4) * num_culled_lgs, &z_widths[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.shatter_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Shatter_Ubo) * num_culled_lgs, &shatter_datas[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.transparencies_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Transparency_Ubo) * num_culled_lgs, &transparency_ubos[0])

    gl.Viewport(0, 0, WIDTH, HEIGHT)

    if EDIT {

        // #####################################################
        //  DRAW EDITOR
        // #####################################################

        draw_editor(rs, shs, es, is, lgs, draw_commands, proj_mat)
    } else {

        // #####################################################
        //  DRAW GAME
        // #####################################################

        // target post-processing buffer 
        // -------------------------------------------
        gl.BindFramebuffer(gl.FRAMEBUFFER, rs.postprocessing_fbo)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        crunch_pt : glm.vec3 = pls.crunch_pt
        player_trail := interpolated_trail(pls, f32(interp_t))
        inverse_view := glm.inverse(only_view_matrix(cs, f32(interp_t)))
        inverse_proj := glm.inverse(only_projection_matrix(cs, f32(interp_t)))
        slide_middle := SLIDE_LEN / 2.0
        slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
        start_slide_t := clamp(pls.slide_state.slide_total / slide_middle, 0, 1) * 0.5
        end_slide_t := clamp(((pls.slide_state.slide_total - slide_off) - (slide_middle)) / slide_middle, 0, 1) * 0.5
        slide_t := start_slide_t + end_slide_t

        // standard geometry
        // -------------------------------------------
        gl.BindVertexArray(rs.standard_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        gl.Enable(gl.DEPTH_TEST)

        use_shader(shs, rs, .Level_Geometry_Fill)
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_float_uniform(shs, "slide_t", slide_t)
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time) / 1000)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(rs^, draw_commands[.Standard][:], gl.PATCHES)

        // bouncy geometry
        // -------------------------------------------
        use_shader(shs, rs, .Bouncy)
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time) / 1000)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_float_uniform(shs, "slide_t", slide_t)
        draw_indirect_render_queue(rs^, draw_commands[.Bouncy][:], gl.PATCHES)

        // wireframe object
        // -------------------------------------------
        gl.Enable(gl.BLEND)

        wireframe_color := [3]f32{0.000, 0.300, 0.600}

        use_shader(shs, rs, .Wireframe)
        set_vec3_uniform(shs, "color", 1, &wireframe_color)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(rs^, draw_commands[.Wireframe][:], gl.LINES)

        // dash barrier
        // -------------------------------------------
        use_shader(shs, rs, .Barrier)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(rs^, draw_commands[.Dash_Barrier][:], gl.PATCHES)

        // background 
        // -------------------------------------------
        gl.BindVertexArray(rs.background_vao)
        gl.Disable(gl.DEPTH_TEST)

        use_shader(shs, rs, .Background)
        if len(pls.screen_splashes) > 0 {
            splashes := pls.screen_splashes[:]
            set_vec4_uniform(shs, "crunch_pts", i32(len(pls.screen_splashes)), &splashes[0])
        }
        set_int_uniform(shs, "crunch_pt_count", i32(len(pls.screen_splashes)))
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

        // geometry outlines
        // -------------------------------------------
        gl.BindVertexArray(rs.standard_vao)
        gl.Disable(gl.BLEND)
        gl.Disable(gl.CULL_FACE)

        geometry_outline_color := [3]f32{0.75, 0.75, 0.75}
        barrier_outline_color := [3]f32{1.0, 0, 0}

        use_shader(shs, rs, .Level_Geometry_Outline)
        set_vec3_uniform(shs, "color", 1, &geometry_outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Standard][:], gl.PATCHES)

        set_vec3_uniform(shs, "color", 1, &barrier_outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Dash_Barrier][:], gl.PATCHES)

        // #####################################################
        //  DRAW PLAYER
        // #####################################################

        // draw_player(rs, pls, shs, f32(time), f32(interp_t))

        gl.BindVertexArray(rs.player_vao)
        gl.Enable(gl.DEPTH_TEST)

        // animate vertices
        // -------------------------------------------
        offset_vertices := make([]Vertex, len(rs.player_geometry.vertices), context.temp_allocator)
        copy(offset_vertices, rs.player_geometry.vertices[:])

        if !(pls.contact_state.state == .ON_WALL) && !pls.slide_state.sliding {
            apply_player_vertices_roll_rotation(offset_vertices[:], pls.velocity, f32(time))
        }
        if pls.slide_state.sliding {
            slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
            animate_player_vertices_sliding(offset_vertices[:], pls.contact_state.contact_ray, pls.slide_state.slide_total, slide_off, f32(time))
        } else if pls.contact_state.state == .ON_GROUND && !pls.slide_state.sliding {
            animate_player_vertices_rolling(offset_vertices[:], pls.contact_state.state, pls.velocity, pls.spike_compression, f32(time))
        } else if pls.contact_state.state == .IN_AIR {
            animate_player_vertices_jumping(offset_vertices[:])
        }
        apply_player_vertices_physics_displacement(offset_vertices[:], pls.particle_displacement, pls.slide_state.sliding)

        // get current player color 
        // -------------------------------------------
        p_color := [3]f32 {1.0, 0.0, 0.0}
        p_outline_color := [3]f32{.5, 0, .5}
        if f32(time) < pls.hurt_t + DAMAGE_LEN {
            p_color = {1.0, 0.0, 1.0}
            p_outline_color = {1.0, 0.0, 1.0}
        }
        if f32(time) < pls.broke_t + BREAK_BOOST_LEN {
            p_color = {0.0, 1.0, 0.0}
            p_outline_color = {0.0, 1.0, 0.0}
        }

        // load vertices into buffer
        // -------------------------------------------
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.player_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(offset_vertices[0]) * len(offset_vertices), raw_data(offset_vertices), gl.STATIC_DRAW) 
        player_mat := interpolated_player_matrix(pls, f32(interp_t))

        // draw body
        // -------------------------------------------
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_fill_ebo)

        use_shader(shs, rs, .Player_Fill)
        set_vec3_uniform(shs, "p_color", 1, &p_color)
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.DrawElements(gl.TRIANGLES, i32(len(rs.player_fill_indices)), gl.UNSIGNED_INT, nil)

        // draw outline
        // -------------------------------------------
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        if pls.contact_state.state == .ON_GROUND {
            gl.LineWidth(1.5)
        } else {
            gl.LineWidth(2)
        }
        if pls.slide_state.sliding {
            gl.LineWidth(0.5)
        }

        use_shader(shs, rs, .Player_Outline)
        set_vec3_uniform(shs, "p_outline_color", 1, &p_outline_color)
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.DrawElements(gl.LINES, i32(len(rs.player_outline_indices)), gl.UNSIGNED_INT, nil)

        // draw dash line
        // -------------------------------------------
        gl.BindVertexArray(rs.lines_vao)
        // gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
        gl.LineWidth(2)

        dash_line_start := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * 4.5;
        dash_line: [2]Line_Vertex = {
            {dash_line_start, 0, {1.0, 0.0, 1.0}},
            {pls.dash_state.dash_end_pos, 1, {1.0, 0.0, 1.0}}
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.DYNAMIC_DRAW)

        green := [3]f32{1.0, 0.0, 1.0}

        use_shader(shs, rs, .Dash_Line)
        set_vec3_uniform(shs, "color", 1, &green)
        set_float_uniform(shs, "resolution", f32(20))
        gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))

        // slide zone (transparent)
        // -------------------------------------------
        gl.BindVertexArray(rs.standard_vao)
        gl.Enable(gl.BLEND)

        use_shader(shs, rs, .Slide_Zone)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(rs^, draw_commands[.Slide_Zone][:], gl.TRIANGLES)

        // slide zone outline
        // -------------------------------------------
        gl.Disable(gl.BLEND)
        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)

        slide_zone_outline_color := [3]f32{0, 0, 1.0}

        use_shader(shs, rs, .Level_Geometry_Outline)
        set_vec3_uniform(shs, "color", 1, &slide_zone_outline_color)
        draw_indirect_render_queue(rs^, draw_commands[.Slide_Zone][:], gl.PATCHES)

        // post-processing
        // -------------------------------------------
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0) 
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.Enable(gl.CULL_FACE)

        use_shader(shs, rs, .Postprocessing)
        screen_ripple_pt := pls.screen_ripple_pt
        set_float_uniform(shs, "time", f32(time))
        set_float_uniform(shs, "crunch_time", f32(pls.crunch_time))
        set_vec2_uniform(shs, "ppos", 1, &screen_ripple_pt)
        gl.BindVertexArray(rs.background_vao)
        gl.BindTexture(gl.TEXTURE_2D, rs.postprocessing_tcb)
        gl.Disable(gl.DEPTH_TEST)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
}
