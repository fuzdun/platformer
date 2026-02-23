package main

import "core:slice"
import "core:strconv"
import "core:math"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import hm "core:container/handle_map"

draw :: proc(
    lgs: Level_Geometry_State, 
    lgrs: ^Level_Geometry_Render_Data_State,
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

    // #####################################################
    //  PREPARE RENDER DATA
    // #####################################################

    // count geometry groups
    // -------------------------------------------
    group_offsets: [NUM_RENDER_GROUPS]int
    min_z_cull := cs.position.z - FWD_Z_CULL
    max_z_cull := cs.position.z + BCK_Z_CULL
    num_culled_rd := 0

    rd_it := hm.iterator_make(lgrs)
    for rd, rd_h in hm.iterate(&rd_it) {
        if EDIT || (rd.transform.position.z < max_z_cull && rd.transform.position.z > min_z_cull) {
            group_offsets[rd.render_group] += 1
            num_culled_rd += 1
        }
    }

    // convert group counts to group offsets

    for &val, idx in group_offsets[1:] {
       val += group_offsets[idx] 
    }
    #reverse for &val, idx in group_offsets {
        val = idx == 0 ? 0 : group_offsets[idx - 1]
    }

    // generate draw commands
    // -------------------------------------------
    draw_commands: Render_Groups
    for &rg in draw_commands {
        rg = make([dynamic]gl.DrawElementsIndirectCommand, context.temp_allocator)
    } 
    for g_off, idx in group_offsets {
        next_off := idx == len(group_offsets) - 1 ? num_culled_rd : group_offsets[idx + 1]
        count := u32(next_off - g_off)
        if count == 0 do continue
        shape := SHAPE(idx % len(SHAPE))
        render_type := Level_Geometry_Render_Type(math.floor(f32(idx) / f32(len(SHAPE))))
        sd := sr.level_geometry[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            count,
            sr.index_offsets[shape],
            sr.vertex_offsets[shape],
            u32(g_off)
        }
        append(&draw_commands[render_type], command)
    }

    culled_rd := make(#soa[]Level_Geometry_Render_Data, num_culled_rd, context.temp_allocator)

    // sort culled geometry
    // -------------------------------------------
    rd_it = hm.iterator_make(lgrs)
    for rd, rd_h in hm.iterate(&rd_it) {
        if EDIT || (rd.transform.position.z < max_z_cull && rd.transform.position.z > min_z_cull) {
            culled_rd[group_offsets[rd.render_group]] = rd^
            group_offsets[rd.render_group] += 1
        }
    }

    // load UBOs 
    // -------------------------------------------
    for ssbo in Ssbo {
        ssbo_mapper(culled_rd, bs, ssbo)
    }

    proj_mat := EDIT ? construct_camera_matrix(cs^) : interpolated_camera_matrix(cs, f32(interp_t))
    i_ppos:[3]f32 = interpolated_player_pos(pls, f32(interp_t))
    i_cpos: [3]f32 = interpolated_camera_pos(cs, f32(interp_t))
    intensity := gs.intensity

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

    combined_ubo : Combined_Ubo = {
        ppos = [4]f32 { i_ppos.x, i_ppos.y, i_ppos.z, 0 },
        cpos = [4]f32 { i_cpos.x, i_cpos.y, i_cpos.z, 0 },
        projection = proj_mat,
        time = f32(time),
        intensity = intensity,
        dash_time = pls.dash_state.dash_time,
        dash_total = f32(time) - pls.dash_state.dash_time,
        constrain_dir = la.normalize0(pls.dash_state.dash_dir),
        inner_tess = INNER_TESSELLATION_AMT,
        outer_tess = OUTER_TESSELLATION_AMT,
    }

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.combined_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Combined_Ubo), &combined_ubo)

    player_trail_vec4: [3][4]f32
    for v, i in interpolated_trail(rs^, f32(interp_t)) {
        player_trail_vec4[i].xyz = v.xyz
    }

    standard_ubo : Standard_Ubo = {
        crunch_pt = [4]f32 { rs.crunch_pt.x, rs.crunch_pt.y, rs.crunch_pt.z, 0 },
        player_trail = player_trail_vec4,
        inverse_view = glm.inverse(only_view_matrix(cs, f32(interp_t))),
        inverse_projection = glm.inverse(only_projection_matrix(cs, f32(interp_t))),
        slide_t = start_slide_t + end_slide_t,
        crunch_t = f32(rs.crunch_time),
    }

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.standard_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(Standard_Ubo), &standard_ubo)

    shatter_delay := f32(BREAK_DELAY)
    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.shatter_delay_ubo)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(f32), &shatter_delay)

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

        // standard geometry
        // -------------------------------------------
        use_shader(shs, rs, bs, .Level_Geometry_Fill)
        draw_indirect_render_queue(bs, draw_commands[.Standard][:], gl.PATCHES)

        // bouncy geometry
        // -------------------------------------------
        use_shader(shs, rs, bs, .Bouncy)
        draw_indirect_render_queue(bs, draw_commands[.Bouncy][:], gl.PATCHES)

        // wireframe object
        // -------------------------------------------
        use_shader(shs, rs, bs, .Wireframe)
        wireframe_color := [3]f32{0.000, 0.300, 0.600}
        set_vec3_uniform(shs, "color", 1, &wireframe_color)
        draw_indirect_render_queue(bs, draw_commands[.Wireframe][:], gl.LINES)

        // dash barrier
        // -------------------------------------------
        use_shader(shs, rs, bs, .Barrier)
        draw_indirect_render_queue(bs, draw_commands[.Dash_Barrier][:], gl.PATCHES)

        // background 
        // -------------------------------------------
        use_shader(shs, rs, bs, .Background)
        if len(rs.screen_splashes) > 0 {
            splashes := rs.screen_splashes[:]
            set_vec4_uniform(shs, "crunch_pts", i32(len(rs.screen_splashes)), &splashes[0])
        }
        set_int_uniform(shs, "crunch_pt_count", i32(len(rs.screen_splashes)))
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

        // geometry outlines
        // -------------------------------------------
        use_shader(shs, rs, bs, .Level_Geometry_Outline)
        geometry_outline_color := [3]f32{0.75, 0.75, 0.75}
        set_vec3_uniform(shs, "color", 1, &geometry_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Standard][:], gl.PATCHES)

        barrier_outline_color := [3]f32{1.0, 0, 0}
        set_vec3_uniform(shs, "color", 1, &barrier_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Dash_Barrier][:], gl.PATCHES)


        // #####################################################
        //  DRAW PLAYER
        // #####################################################


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

        // draw body
        // -------------------------------------------
        use_shader(shs, rs, bs, .Player_Fill)
        set_vec3_uniform(shs, "p_color", 1, &p_color)
        player_mat := interpolated_player_matrix(pls, f32(interp_t))
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_fill_ebo)
        gl.DrawElements(gl.TRIANGLES, i32(len(sr.player_fill_indices)), gl.UNSIGNED_INT, nil)

        // draw outline
        // -------------------------------------------
        use_shader(shs, rs, bs, .Player_Outline)
        set_vec3_uniform(shs, "p_outline_color", 1, &p_outline_color)
        set_matrix_uniform(shs, "transform", &player_mat)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_outline_ebo)
        gl.DrawElements(gl.LINES, i32(len(sr.player_outline_indices)), gl.UNSIGNED_INT, nil)

        // draw dash line
        // -------------------------------------------
        dash_line_start := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * 4.5;
        dash_line_end := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * DASH_DIST
        dash_line: [2]Line_Vertex = {
            {dash_line_start, 0, {1.0, 0.0, 1.0}},
            {dash_line_end, 1, {1.0, 0.0, 1.0}}
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.STATIC_DRAW)

        green := [3]f32{1.0, 0.0, 1.0}

        use_shader(shs, rs, bs, .Dash_Line)
        set_vec3_uniform(shs, "color", 1, &green)
        set_float_uniform(shs, "resolution", f32(20))
        gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))


        // #####################################################
        //  DRAW OTHER
        // #####################################################

        // slide zone (transparent)
        // -------------------------------------------
        use_shader(shs, rs, bs, .Slide_Zone)
        set_float_uniform(shs, "shatter_delay", f32(BREAK_DELAY))
        draw_indirect_render_queue(bs, draw_commands[.Slide_Zone][:], gl.TRIANGLES)

        // particles
        // -------------------------------------------
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

        use_shader(shs, rs, bs, .Trail_Particle)
        set_float_uniform(shs, "interp_t", f32(interp_t))
        set_float_uniform(shs, "delta_time", dt)
        // set_float_uniform(shs, "radius", FIXED_DELTA_TIME)
        set_vec3_uniform(shs, "camera_dir", 1, &camera_fwd_worldspace)
        gl.DrawArrays(gl.POINTS, 0, i32(ptcls.player_burst_particles.particles.len))


        // slide zone outline
        // -------------------------------------------
        use_shader(shs, rs, bs, .Level_Geometry_Outline)
        slide_zone_outline_color := [3]f32{1.0, 0, 1.0}
        set_vec3_uniform(shs, "color", 1, &slide_zone_outline_color)
        draw_indirect_render_queue(bs, draw_commands[.Slide_Zone][:], gl.PATCHES)

        // spin trails
        // -------------------------------------------
        use_shader(shs, rs, bs, .Spin_Trails)
        spin_trail_off := glm.mat4Translate(i_ppos)
        spin_trail_rotation_1 := la.matrix4_rotate_f32(f32(time) / 300, [3]f32{1, 0, 0})
        player_velocity_dir := la.normalize0(pls.velocity.xz)
        spin_trail_rotation_2 := la.matrix4_rotate_f32(la.atan2(player_velocity_dir.x, player_velocity_dir.y), [3]f32{0, 1, 0})
        spin_trail_transform := spin_trail_off * spin_trail_rotation_2 * spin_trail_rotation_1
        set_matrix_uniform(shs, "transform", &spin_trail_transform)
        set_float_uniform(shs, "spin_amt", pls.spin_state.spin_amt)
        if pls.spin_state.spin_amt > 0 {
            gl.DrawElements(gl.TRIANGLES, i32(len(sr.level_geometry[.SPIN_TRAIL].indices)), gl.UNSIGNED_INT, nil)
        }
        
        // UI text
        // -------------------------------------------
        use_shader(shs, rs, bs, .Text)
        score_buf: [8]byte
        strconv.write_int(score_buf[:], i64(gs.score), 10)
        render_screen_text(shs, bs, string(score_buf[:]), [3]f32{-0.9, 0.75, 0}, la.MATRIX4F32_IDENTITY, .3)

        if gs.time_remaining > 0 {
           for hop_idx in 0..<pls.hops_remaining {
               render_screen_text(shs, bs, "S", [3]f32{0.35, 0.075 - (0.075 * f32(hop_idx)), 0}, la.MATRIX4F32_IDENTITY, .3)
           }
           time_buf: [4]byte
           strconv.write_int(time_buf[:], i64(gs.time_remaining), 10)
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

        use_shader(shs, rs, bs, .Postprocessing)
        // set_float_uniform(shs, "crunch_time", f32(rs.crunch_time))
        screen_ripple_pt := rs.screen_ripple_pt
        set_vec2_uniform(shs, "ripple_pt", 1, &screen_ripple_pt)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
}
