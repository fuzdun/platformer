package main

import "constants"
import "core:sort"
import "core:fmt"
import "core:slice"
import "core:math"
import "core:strconv"
import vmem "core:mem/virtual"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import tim "core:time"

draw :: proc(
    lgs: #soa[]Level_Geometry, 
    sr: Shape_Resources,
    pls: Player_State,
    rs: ^Render_State,
    ptcls: ^Particle_State,
    bs: Buffer_State,
    shs: ^Shader_State,
    ps: ^Physics_State,
    cs: ^Camera_State,
    is: Input_State,
    es: Editor_State,
    szs: Slide_Zone_State,
    gs: Game_State,
    time: f64,
    interp_t: f64,
    dt: f32
) {
    using constants

    // #####################################################
    //  PREPARE RENDER DATA
    // #####################################################

    // count geometry groups
    // -------------------------------------------
    group_offsets: [NUM_RENDER_GROUPS]int
    min_z_cull := cs.position.z - FWD_Z_CULL
    max_z_cull := cs.position.z + BCK_Z_CULL
    num_culled_lgs := 0
    for lg, idx in lgs {
        if EDIT || (lg.transform.position.z < max_z_cull && lg.transform.position.z > min_z_cull) {
            group_offsets[lg_render_group(lg)] += 1
            num_culled_lgs += 1
        }
    }

    // generate draw commands 
    // -------------------------------------------
    counts_to_offsets(group_offsets[:])
    draw_commands := offsets_to_render_commands(group_offsets[:], num_culled_lgs, rs^, sr)

    // sort and cull
    // -------------------------------------------
    culled_lgs := make(#soa[]Level_Geometry, num_culled_lgs, context.temp_allocator)
    for lg, idx in lgs {
        if EDIT || (lg.transform.position.z < max_z_cull && lg.transform.position.z > min_z_cull) {
            rg := lg_render_group(lg)
            culled_lgs[group_offsets[rg]] = lg
            group_offsets[rg] += 1
        }
    }

    // load UBOs 
    // -------------------------------------------
    transforms, angular_velocities,
    shapes, colliders, render_types,
    attributess, aabbs, shatter_datas,
    transparencies := soa_unzip(culled_lgs[:])

    proj_mat := EDIT ? construct_camera_matrix(cs^) : interpolated_camera_matrix(cs, f32(interp_t))
    i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))
    intensity := gs.intensity

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

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.common_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Common_Ubo), &common_ubo)

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.dash_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Dash_Ubo), &dash_ubo)

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.ppos_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.vec3), &i_ppos[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.tess_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Tess_Ubo), &tess_ubo)

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.transforms_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.mat4) * num_culled_lgs, &transform_mats[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.z_widths_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.vec4) * num_culled_lgs, &z_widths[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.shatter_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Shatter_Ubo) * num_culled_lgs, &shatter_datas[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.transparencies_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Transparency_Ubo) * num_culled_lgs, &transparency_ubos[0])

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.intensity_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(f32), &intensity)

    gl.Viewport(0, 0, WIDTH, HEIGHT)

    if EDIT {


        // #####################################################
        //  DRAW EDITOR
        // #####################################################

        draw_editor(rs, bs, shs, es, is, lgs, draw_commands, proj_mat)
    } else {


        // #####################################################
        //  DRAW GAME
        // #####################################################

        // target post-processing buffer 
        // -------------------------------------------
        gl.BindFramebuffer(gl.FRAMEBUFFER, bs.postprocessing_fbo)
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        crunch_pt : glm.vec3 = rs.crunch_pt
        player_trail := interpolated_trail(rs^, f32(interp_t))
        inverse_view := glm.inverse(only_view_matrix(cs, f32(interp_t)))
        inverse_proj := glm.inverse(only_projection_matrix(cs, f32(interp_t)))
        slide_middle := SLIDE_LEN / 2.0
        slide_total := f32(time) - pls.slide_state.slide_time 
    
    
        slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
        start_slide_t := clamp(slide_total / slide_middle, 0, 1) * 0.5
        end_slide_t := clamp(((slide_total - slide_off) - (slide_middle)) / slide_middle, 0, 1) * 0.5
        slide_t := start_slide_t + end_slide_t
        camera_right_worldspace: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
        camera_right_worldspace = la.normalize(camera_right_worldspace)
        camera_up_worldspace: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
        camera_up_worldspace = la.normalize(camera_up_worldspace)
        camera_fwd_worldspace: [3]f32 = {proj_mat[0][2], proj_mat[1][2], proj_mat[2][2]}
        camera_fwd_worldspace = la.normalize(camera_fwd_worldspace)

        // standard geometry
        // -------------------------------------------
        gl.BindVertexArray(bs.standard_vao)
        gl.BindTexture(gl.TEXTURE_2D, bs.dither_tex)
        gl.Enable(gl.DEPTH_TEST)

        use_shader(shs, rs, .Level_Geometry_Fill)
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_float_uniform(shs, "slide_t", slide_t)
        set_float_uniform(shs, "crunch_time", f32(rs.crunch_time) / 1000)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(bs, draw_commands[.Standard][:], gl.PATCHES)

        // bouncy geometry
        // -------------------------------------------
        use_shader(shs, rs, .Bouncy)
        set_vec3_uniform(shs, "crunch_pt", 1, &crunch_pt)
        set_vec3_uniform(shs, "player_trail", 3, &player_trail[0])
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_float_uniform(shs, "crunch_time", f32(rs.crunch_time) / 1000)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_float_uniform(shs, "slide_t", slide_t)
        draw_indirect_render_queue(bs, draw_commands[.Bouncy][:], gl.PATCHES)

        // wireframe object
        // -------------------------------------------
        gl.Enable(gl.BLEND)

        wireframe_color := [3]f32{0.000, 0.300, 0.600}

        use_shader(shs, rs, .Wireframe)
        set_vec3_uniform(shs, "color", 1, &wireframe_color)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(bs, draw_commands[.Wireframe][:], gl.LINES)

        // dash barrier
        // -------------------------------------------
        use_shader(shs, rs, .Barrier)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        set_matrix_uniform(shs, "inverse_view", &inverse_view)
        set_matrix_uniform(shs, "inverse_projection", &inverse_proj)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        draw_indirect_render_queue(bs, draw_commands[.Dash_Barrier][:], gl.PATCHES)

        // background 
        // -------------------------------------------
        gl.BindVertexArray(bs.background_vao)
        gl.Disable(gl.DEPTH_TEST)

        use_shader(shs, rs, .Background)
        if len(rs.screen_splashes) > 0 {
            splashes := rs.screen_splashes[:]
            set_vec4_uniform(shs, "crunch_pts", i32(len(rs.screen_splashes)), &splashes[0])
        }
        set_int_uniform(shs, "crunch_pt_count", i32(len(rs.screen_splashes)))
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

        // geometry outlines
        // -------------------------------------------
        gl.BindVertexArray(bs.standard_vao)
        gl.Disable(gl.BLEND)
        gl.Disable(gl.CULL_FACE)

        geometry_outline_color := [3]f32{0.75, 0.75, 0.75}
        barrier_outline_color := [3]f32{1.0, 0, 0}

        use_shader(shs, rs, .Level_Geometry_Outline)
        set_vec3_uniform(shs, "color", 1, &geometry_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Standard][:], gl.PATCHES)

        set_vec3_uniform(shs, "color", 1, &barrier_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Dash_Barrier][:], gl.PATCHES)


        // #####################################################
        //  DRAW PLAYER
        // #####################################################

        gl.BindVertexArray(bs.player_vao)
        gl.Enable(gl.DEPTH_TEST)

        // animate vertices
        // -------------------------------------------
        offset_vertices := make([]Vertex, len(sr.player_vertices), context.temp_allocator)
        copy(offset_vertices, sr.player_vertices[:])

        if !(pls.contact_state.state == .ON_WALL) && !(pls.mode == .Sliding) {
            apply_player_vertices_roll_rotation(offset_vertices[:], pls.velocity, f32(time))
        }
        if pls.mode == .Sliding {
            slide_off := pls.slide_state.mid_slide_time - pls.slide_state.slide_time
            animate_player_vertices_sliding(offset_vertices[:], pls.contact_state.contact_ray, slide_total, slide_off, f32(time))
        } else if pls.contact_state.state == .ON_GROUND && !(pls.mode == .Sliding) {
            animate_player_vertices_rolling(offset_vertices[:], pls.contact_state.state, pls.velocity, rs.player_spike_compression, f32(time))
        } else if pls.contact_state.state == .IN_AIR {
            animate_player_vertices_jumping(offset_vertices[:])
        }
        apply_player_vertices_physics_displacement(offset_vertices[:], rs.player_vertex_displacment, pls.mode == .Sliding)

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
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.player_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(offset_vertices[0]) * len(offset_vertices), raw_data(offset_vertices), gl.STATIC_DRAW) 
        player_mat := interpolated_player_matrix(pls, f32(interp_t))

        // draw body
        // -------------------------------------------
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_fill_ebo)

        use_shader(shs, rs, .Player_Fill)
        set_vec3_uniform(shs, "p_color", 1, &p_color)
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.DrawElements(gl.TRIANGLES, i32(len(sr.player_fill_indices)), gl.UNSIGNED_INT, nil)

        // draw outline
        // -------------------------------------------
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_outline_ebo)
        if pls.contact_state.state == .ON_GROUND {
            gl.LineWidth(1.5)
        } else {
            gl.LineWidth(2)
        }
        if pls.mode == .Sliding {
            gl.LineWidth(0.5)
        }

        use_shader(shs, rs, .Player_Outline)
        set_vec3_uniform(shs, "p_outline_color", 1, &p_outline_color)
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.DrawElements(gl.LINES, i32(len(sr.player_outline_indices)), gl.UNSIGNED_INT, nil)

        // draw dash line
        // -------------------------------------------
        gl.Disable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
        gl.BindVertexArray(bs.lines_vao)
        gl.LineWidth(2)

        dash_line_start := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * 4.5;
        dash_line_end := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * DASH_DIST
        dash_line: [2]Line_Vertex = {
            {dash_line_start, 0, {1.0, 0.0, 1.0}},
            {dash_line_end, 1, {1.0, 0.0, 1.0}}
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.STATIC_DRAW)

        green := [3]f32{1.0, 0.0, 1.0}

        use_shader(shs, rs, .Dash_Line)
        set_vec3_uniform(shs, "color", 1, &green)
        set_float_uniform(shs, "resolution", f32(20))
        gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))


        // #####################################################
        //  DRAW OTHER
        // #####################################################

        // slide zone (transparent)
        // -------------------------------------------
        gl.BindVertexArray(bs.standard_vao)
        // gl.Disable(gl.BLEND)

        use_shader(shs, rs, .Slide_Zone)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(bs, draw_commands[.Slide_Zone][:], gl.TRIANGLES)

        pv := PARTICLE_VERTICES
        for &pv in pv {
            pv.position = (camera_right_worldspace * pv.position.x + camera_up_worldspace * pv.position.y) * 1.0
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.particle_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(pv[0]) * len(pv), &pv[0])

        particle_count := ptcls.player_burst_particles.particles.len
        if particle_count > 0 {
            sorted_pp := make([][4]f32, particle_count, context.temp_allocator)
            copy_slice(sorted_pp, ptcls.player_burst_particles.particles.values[:particle_count])
            context.user_ptr = &cs.position
            z_sort := proc(a: [4]f32, b: [4]f32) -> bool {
                cam_pos := (cast(^[3]f32) context.user_ptr)^
                return la.length2(a.xyz - cam_pos) > la.length2(b.xyz - cam_pos)
            }
            slice.sort_by(sorted_pp[:], z_sort)
        }

        gl.BindVertexArray(bs.trail_particle_vao)
        use_shader(shs, rs, .Trail_Particle)
        set_float_uniform(shs, "interp_t", f32(interp_t))
        set_float_uniform(shs, "delta_time", dt)
        // set_float_uniform(shs, "radius", FIXED_DELTA_TIME)
        set_vec3_uniform(shs, "camera_dir", 1, &camera_fwd_worldspace)
        gl.DrawArrays(gl.POINTS, 0, i32(ptcls.player_burst_particles.particles.len))


        // slide zone outline
        // -------------------------------------------
        gl.BindVertexArray(bs.standard_vao)
        gl.Disable(gl.BLEND)
        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)

        slide_zone_outline_color := [3]f32{1.0, 0, 1.0}

        use_shader(shs, rs, .Level_Geometry_Outline)
        set_vec3_uniform(shs, "color", 1, &slide_zone_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Slide_Zone][:], gl.PATCHES)

        // draw spin trails
        // -------------------------------------------
        gl.BindVertexArray(bs.spin_trails_vao)
        gl.Enable(gl.BLEND)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)

        spin_trail_off := glm.mat4Translate(i_ppos)
        spin_trail_rotation_1 := la.matrix4_rotate_f32(f32(time) / 300, [3]f32{1, 0, 0})
        player_velocity_dir := la.normalize0(pls.velocity.xz)
        spin_trail_rotation_2 := la.matrix4_rotate_f32(la.atan2(player_velocity_dir.x, player_velocity_dir.y), [3]f32{0, 1, 0})
        spin_trail_transform := spin_trail_off * spin_trail_rotation_2 * spin_trail_rotation_1


        gl.BindBuffer(gl.ARRAY_BUFFER, bs.spin_trails_vbo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.spin_trails_ebo)

        use_shader(shs, rs, .Spin_Trails)
        set_matrix_uniform(shs, "transform", &spin_trail_transform)
        set_vec3_uniform(shs, "camera_pos", 1, &cs.position)
        set_float_uniform(shs, "spin_amt", pls.spin_state.spin_amt)

        if pls.spin_state.spin_amt > 0 {
            gl.DrawElements(gl.TRIANGLES, i32(len(sr.level_geometry[.SPIN_TRAIL].indices)), gl.UNSIGNED_INT, nil)
        }
        
        gl.BindVertexArray(bs.text_vao)
        use_shader(shs, rs, .Text)

        score_buf: [8]byte
        strconv.itoa(score_buf[:], gs.score)
        render_screen_text(shs, bs, string(score_buf[:]), [3]f32{-0.9, 0.75, 0}, la.MATRIX4F32_IDENTITY, .3)

        if gs.time_remaining > 0 {

            for hop_idx in 0..<pls.hops_remaining {
                render_screen_text(shs, bs, "S", [3]f32{0.35, 0.075 - (0.075 * f32(hop_idx)), 0}, la.MATRIX4F32_IDENTITY, .3)
            }

            time_buf: [4]byte
            strconv.itoa(time_buf[:], int(gs.time_remaining))
            render_screen_text(shs, bs, string(time_buf[:]), [3]f32{0.0, 0.65, 0}, la.MATRIX4F32_IDENTITY, .3)
        }
        
        if f32(time) - gs.last_checkpoint_t < 2000 {
            render_screen_text(shs, bs, "checkpoint (+10)", [3]f32{0.1, 0.65, 0}, la.MATRIX4F32_IDENTITY, .2)
        }

        // post-processing
        // -------------------------------------------
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0) 
        gl.ClearColor(0, 0, 0, 1)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.Enable(gl.CULL_FACE)

        use_shader(shs, rs, .Postprocessing)
        screen_ripple_pt := rs.screen_ripple_pt
        set_float_uniform(shs, "time", f32(time))
        set_float_uniform(shs, "crunch_time", f32(rs.crunch_time))
        set_vec2_uniform(shs, "ppos", 1, &screen_ripple_pt)
        gl.BindVertexArray(bs.background_vao)
        gl.BindTexture(gl.TEXTURE_2D, bs.postprocessing_tcb)
        gl.Disable(gl.DEPTH_TEST)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
}
