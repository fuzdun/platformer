package main
import gl "vendor:OpenGL"
import la "core:math/linalg"
import rand "core:math/rand"
import "core:fmt"

draw_player :: proc(rs: ^Render_State, pls: Player_State, shs: ^Shader_State, time: f32, interp_t: f32) {
    gl.BindVertexArray(rs.player_vao)
    offset_vertices := make([]Vertex, len(rs.player_geometry.vertices)); defer delete(offset_vertices)
    copy(offset_vertices, rs.player_geometry.vertices[:])
    displacement_dir := la.normalize0(pls.particle_displacement)

    // calculate animated primitive vertices
    vel_dir: [3]f32 = pls.velocity.xz == 0 ? {0, 0, -1} : la.normalize0(pls.velocity)
    rot_mat := la.matrix4_rotate_f32(f32(time) / 100, la.cross([3]f32{0, 1, 0}, vel_dir))
    stretch_dir := la.normalize(-la.normalize(pls.velocity) - {0, 0.5, 0})
    right_vec := la.cross([3]f32{0, 1, 0}, la.normalize0(pls.velocity)) 

    for &v, idx in offset_vertices {
        rand.reset(u64(idx))
        if !pls.slide_state.sliding && !(pls.contact_state.state == .ON_WALL) {
            v.pos = la.matrix_mul_vector(rot_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 0.0}).xyz
        }
        if v.uv.x != 1.0 {
            v.pos *= f32(pls.spike_compression)
        } else {
            if pls.contact_state.state == .ON_GROUND&& !pls.slide_state.sliding {
                norm_pos := la.normalize(v.pos - (la.dot(v.pos, right_vec) * right_vec * 0.5))
                down_alignment := max(0.25, min(0.75, la.dot(norm_pos, [3]f32{0, -1, 0})))
                down_alignment = (down_alignment - 0.25) / 0.5

                stretch_alignment := max(0.5, min(1.0, la.dot(norm_pos, stretch_dir)))
                stretch_alignment = (stretch_alignment - 0.5) / 0.5
                stretch_amt := stretch_alignment * stretch_alignment * la.length(pls.velocity) / 40.0

                v.pos *= (1.0 - down_alignment * 0.5)
                v.pos *= 1.0 + stretch_amt
            }
        }
        if pls.slide_state.sliding {
            up := la.normalize(pls.contact_state.contact_ray)
            spin_mat := la.matrix4_rotate_f32(f32(time) / 200, up)
            slide_t := time - pls.slide_state.slide_time
            end_slide_t := time - (SLIDE_LEN + pls.slide_state.slide_time - SLIDE_ANIM_EASE_LEN)
            compression_t := clamp(slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0) - clamp(end_slide_t / SLIDE_ANIM_EASE_LEN, 0.0, 1.0)
            vertical_fact := la.dot(up, v.pos)
            v.pos -= up * vertical_fact * easeout_cubic(compression_t) * abs(vertical_fact)
            if v.uv.x == 1.0 {
                v.pos *= (1.0 + (compression_t) * 5.0)
            }
            v.pos = la.matrix_mul_vector(spin_mat, [4]f32{v.pos[0], v.pos[1], v.pos[2], 0.0}).xyz
        }

        if pls.contact_state.state == .ON_GROUND {
            v.pos *= 1.2
        } 

        displacement_fact := la.dot(displacement_dir, la.normalize0(v.pos))
        if displacement_fact > 0.25 {
            displacement_fact *= 0.5
        }
        if !pls.slide_state.sliding {
            v.pos = la.clamp_length(v.pos + pls.particle_displacement * displacement_fact * 0.030, 3.0)
            v.pos += pls.particle_displacement * displacement_fact * 0.030
        }
    }

    // load vertices into buffer
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.player_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(offset_vertices[0]) * len(offset_vertices), raw_data(offset_vertices), gl.STATIC_DRAW) 
    p_color := [3]f32 {1.0, 0.0, 0.0}
    p_outline_color := [3]f32{.5, 0, .5}
    if time < pls.hurt_t + DAMAGE_LEN {
        p_color = {1.0, 1.0, 0.0}
        p_outline_color = {1.0, 1.0, 0.0}
    }
    if time < pls.broke_t + BREAK_BOOST_LEN {
        p_color = {0.0, 0.0, 1.0}
        p_outline_color = {0.0, 0.0, 1.0}
    }
    if pls.slide_state.sliding {
        // p_color = {0.0, 1.0, 1.0}
        // p_outline_color = {0.0, 1.0, 1.0}
        
    }
    player_mat := interpolated_player_matrix(pls, f32(interp_t))

    gl.Disable(gl.CULL_FACE)

    // draw body
    use_shader(shs, rs, .Player_Fill)
    set_vec3_uniform(shs, "p_color", 1, &p_color)
    set_matrix_uniform(shs, "transform", &player_mat)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_fill_ebo)
    gl.DrawElements(gl.TRIANGLES, i32(len(rs.player_fill_indices)), gl.UNSIGNED_INT, nil)

    // draw body outline
    use_shader(shs, rs, .Player_Outline)
    set_vec3_uniform(shs, "p_outline_color", 1, &p_outline_color)
    set_matrix_uniform(shs, "transform", &player_mat)
    if pls.contact_state.state == .ON_GROUND {
        gl.LineWidth(1.5)
    } else {
        gl.LineWidth(2)
    }
    if pls.slide_state.sliding {
        gl.LineWidth(0.5)
    }
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
    gl.DrawElements(gl.LINES, i32(len(rs.player_outline_indices)), gl.UNSIGNED_INT, nil)

    gl.Enable(gl.CULL_FACE)

    // draw dash line
    use_shader(shs, rs, .Dash_Line)
    gl.BindVertexArray(rs.lines_vao)
    green := [3]f32{1.0, 0.0, 1.0}
    set_vec3_uniform(shs, "color", 1, &green)
    set_float_uniform(shs, "resolution", f32(20))
    dash_line_start := pls.dash_state.dash_start_pos + pls.dash_state.dash_dir * 4.5;
    dash_line: [2]Line_Vertex = {
        {dash_line_start, 0, {1.0, 0.0, 1.0}},
        {pls.dash_state.dash_end_pos, 1, {1.0, 0.0, 1.0}}
    }
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(dash_line[0]) * len(dash_line), &dash_line[0], gl.DYNAMIC_DRAW)
    gl.LineWidth(2)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.DrawArrays(gl.LINES, 0, i32(len(dash_line)))
    gl.Disable(gl.BLEND)
}

