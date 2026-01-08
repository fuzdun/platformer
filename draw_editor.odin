package main
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:strconv"
import "core:fmt"

draw_editor :: proc(rs: ^Render_State, shs: ^Shader_State, es: Editor_State, is: Input_State, lgs: Level_Geometry_State, rg: Render_Groups, proj_mat: glm.mat4) {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0) 
    gl.ClearColor(0, 0, 0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    gl.Enable(gl.DEPTH_TEST)

    gl.BindVertexArray(rs.standard_vao)

    // draw geometry (w/ outlines)
    use_shader(shs, rs, .Editor_Geometry)
    set_int_uniform(shs, "selected_index", i32(es.selected_entity))

    draw_indirect_render_queue(rs^, rg[.Standard][:], gl.TRIANGLES)
    draw_indirect_render_queue(rs^, rg[.Dash_Barrier][:], gl.TRIANGLES)
    draw_indirect_render_queue(rs^, rg[.Wireframe][:], gl.TRIANGLES)
    draw_indirect_render_queue(rs^, rg[.Slide_Zone][:], gl.TRIANGLES)
    draw_indirect_render_queue(rs^, rg[.Bouncy][:], gl.TRIANGLES)

    // draw geometry outlines
    // use_shader(shs, rs, .Level_Geometry_Outline)
    // draw_indirect_render_queue(rs^, rg[.Standard][:], gl.TRIANGLES)
    // draw_indirect_render_queue(rs^, rg[.Dash_Barrier][:], gl.TRIANGLES)
    // draw_indirect_render_queue(rs^, rg[.Wireframe][:], gl.TRIANGLES)
    // draw_indirect_render_queue(rs^, rg[.Slide_Zone][:], gl.TRIANGLES)

    // draw geometry connections
    lines := make([dynamic]Line_Vertex); defer delete(lines)
    gl.BindVertexArray(rs.text_vao)
    use_shader(shs, rs, .Text)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    if len(es.connections) > 0 {
        // scale := es.zoom / 800
        scale: f32 = 0.2
        for el in es.connections {
            append(
                &lines,
                Line_Vertex{el.poss[0], 0, {1, 0, 0}},
                Line_Vertex{el.poss[1], 1, {1, 0, 0}}
            )
            avg_pos := el.poss[0] + (el.poss[1] - el.poss[0]) / 2
            dist_txt_buf: [3]byte            
            strconv.itoa(dist_txt_buf[:], el.dist)
            render_screen_text(shs, rs, string(dist_txt_buf[:]), avg_pos, proj_mat, scale)
        }
    }

    if is.lctrl_pressed {
        for lg, lg_idx in lgs {
            buf: [4]byte
            idx_string := strconv.itoa(buf[:], lg_idx)
            render_screen_text(shs, rs, idx_string, lg.transform.position, proj_mat, 0.3)
        }
    }

    // draw player spawn marker
    ppos := INIT_PLAYER_POS
    append(&lines, Line_Vertex{INIT_PLAYER_POS - [3]f32{0, SPAWN_MARKER_LEN, 0}, 0, SPAWN_MARKER_COL})
    append(&lines, Line_Vertex{INIT_PLAYER_POS + [3]f32{0, SPAWN_MARKER_LEN, 0}, 1, SPAWN_MARKER_COL})

    append(&lines, Line_Vertex{INIT_PLAYER_POS - [3]f32{SPAWN_MARKER_LEN, 0, 0}, 0, SPAWN_MARKER_COL})
    append(&lines, Line_Vertex{INIT_PLAYER_POS + [3]f32{SPAWN_MARKER_LEN, 0, 0}, 1, SPAWN_MARKER_COL})

    append(&lines, Line_Vertex{INIT_PLAYER_POS - [3]f32{0, 0, SPAWN_MARKER_LEN}, 0, SPAWN_MARKER_COL})
    append(&lines, Line_Vertex{INIT_PLAYER_POS + [3]f32{0, 0, SPAWN_MARKER_LEN}, 1, SPAWN_MARKER_COL})

    // draw object guidelines
    epos := es.pos
    append(&lines, Line_Vertex{epos - [3]f32{0, GUIDELINE_LEN, 0}, 0, GUIDELINE_COL})
    append(&lines, Line_Vertex{epos + [3]f32{0, GUIDELINE_LEN, 0}, 1, GUIDELINE_COL})

    append(&lines, Line_Vertex{epos - [3]f32{GUIDELINE_LEN, 0, 0}, 0, GUIDELINE_COL})
    append(&lines, Line_Vertex{epos + [3]f32{GUIDELINE_LEN, 0, 0}, 1, GUIDELINE_COL})

    append(&lines, Line_Vertex{epos - [3]f32{0, 0, GUIDELINE_LEN}, 0, GUIDELINE_COL})
    append(&lines, Line_Vertex{epos + [3]f32{0, 0, GUIDELINE_LEN}, 1, GUIDELINE_COL})


    // draw chunk borders
    chunk_origin := [3]f32{0, 0, 0}
    chunk_w_vector := [3]f32{CHUNK_WIDTH, 0, 0}
    chunk_d_vector := [3]f32{0, 0, -CHUNK_DEPTH}
    append(&lines, Line_Vertex{chunk_origin, 0, CHUNK_BORDER_COL})
    append(&lines, Line_Vertex{chunk_origin + chunk_w_vector, 1, CHUNK_BORDER_COL})

    append(&lines, Line_Vertex{chunk_origin, 0, CHUNK_BORDER_COL})
    append(&lines, Line_Vertex{chunk_origin + chunk_d_vector, 1, CHUNK_BORDER_COL})

    append(&lines, Line_Vertex{chunk_origin + chunk_d_vector, 0, CHUNK_BORDER_COL})
    append(&lines, Line_Vertex{chunk_origin + chunk_d_vector + chunk_w_vector, 1, CHUNK_BORDER_COL})

    append(&lines, Line_Vertex{chunk_origin + chunk_w_vector, 0, CHUNK_BORDER_COL})
    append(&lines, Line_Vertex{chunk_origin + chunk_w_vector + chunk_d_vector, 1, CHUNK_BORDER_COL})



    // draw grid
    grid_lines := make([dynamic]Line_Vertex); defer delete(grid_lines)
    grid_sz_2 := GRID_LINES / 2
    grid_len_2: f32 = GRID_LEN / 2
    grid_step: f32 = GRID_LEN / GRID_LINES
    for xi in -grid_sz_2..=grid_sz_2 {
        for yi in -grid_sz_2..=grid_sz_2 {
            append(&grid_lines, Line_Vertex{[3]f32{f32(xi) * grid_step, f32(yi) * 100, -grid_len_2}, 0, GRID_COL})
            append(&grid_lines, Line_Vertex{[3]f32{f32(xi) * grid_step, f32(yi) * 100,  grid_len_2}, 0, GRID_COL})

            append(&grid_lines, Line_Vertex{[3]f32{f32(xi) * grid_step, -grid_len_2, f32(yi) * 100}, 0, GRID_COL})
            append(&grid_lines, Line_Vertex{[3]f32{f32(xi) * grid_step,  grid_len_2, f32(yi) * 100}, 0, GRID_COL})

            append(&grid_lines, Line_Vertex{[3]f32{-grid_len_2, f32(xi) * grid_step, f32(yi) * 100}, 0, GRID_COL})
            append(&grid_lines, Line_Vertex{[3]f32{ grid_len_2, f32(xi) * grid_step, f32(yi) * 100}, 0, GRID_COL})
        }
    }

    gl.Disable(gl.BLEND)
    gl.BindVertexArray(rs.lines_vao)

    use_shader(shs, rs, .Static_Line)
    gl.LineWidth(2.5)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(lines[0]) * len(lines), &lines[0], gl.DYNAMIC_DRAW)
    gl.DrawArrays(gl.LINES, 0, i32(len(lines)))

    use_shader(shs, rs, .Grid_Line)
    gl.LineWidth(1.5)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(grid_lines[0]) * len(grid_lines), &grid_lines[0], gl.DYNAMIC_DRAW)
    set_vec3_uniform(shs, "edit_pos", 1, &epos)
    gl.DrawArrays(gl.LINES, 0, i32(len(grid_lines)))
}
