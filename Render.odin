package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"
import tm "core:time"

I_MAT :: glm.mat4(1.0)

Render_State :: struct {
    vertices: [dynamic]Vertex,
    //front_zs: [dynamic]f32,
    static_z_width_ssbo: u32,
    indices_ssbo: u32,
    particle_offsets_ssbo: u32,
    static_indices_queue: [ProgramName][dynamic]u16,
    standard_vao: u32,
    particle_vao: u32,
    standard_vbo: u32,
    particle_vbo: u32,
}

load_geometry_data :: proc(gs: ^Game_State) {
    names := [?]string {"basic_cube"}
    for name in names {
        if ok := load_blender_model(name, gs); ok {
            fmt.println("loaded", name) 
        }
    }
}

init_render_buffers :: proc(gs: ^Game_State, rs: ^Render_State) {
    add_player_sphere_data(gs)
    rs.vertices = make([dynamic]Vertex)
    for program in ProgramName {
        rs.static_indices_queue[program] = make([dynamic]u16) 
    }
}

clear_render_queues :: proc(rs: ^Render_State) {
    clear(&rs.vertices)
    for &arr in rs.static_indices_queue {
        clear(&arr)
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    delete(rs.vertices)
    for iq in rs.static_indices_queue do delete(iq)
}

init_draw :: proc(rs: ^Render_State, ss: ^ShaderState) {
    init_shaders(ss)

    gl.GenBuffers(1, &rs.static_z_width_ssbo)
    gl.GenBuffers(1, &rs.indices_ssbo)

    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenBuffers(1, &rs.standard_vbo)
    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, b_uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)

    gl.GenVertexArrays(1, &rs.particle_vao)
    gl.GenBuffers(1, &rs.particle_vbo)
    gl.BindVertexArray(rs.particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, uv))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

init_level_render_data :: proc(gs: ^Game_State, shst: ^ShaderState, rs: ^Render_State) {
    z_widths := make([dynamic]f32); defer delete(z_widths)
    for lg in gs.level_geometry {
        sd := gs.level_resources[lg.shape]
        if !(.Angular_Velocity in lg.attributes) {
            indices_offset := u16(len(rs.vertices))
            for shader in lg.shaders {
                for ind in sd.indices {
                    append(&rs.static_indices_queue[shader], ind + indices_offset)
                }
            }
            min_z := max(f32)
            max_z := min(f32)
            for v in sd.vertices {
                tv := transformed_vertex(v, lg.transform)
                min_z = min(tv.pos.z, min_z) 
                max_z = max(tv.pos.z, max_z)
                append(&rs.vertices, tv)
            }
            z_diff := max_z - min_z
            append(&z_widths, z_diff, z_diff, z_diff)
        } 
    }
    for shader in ProgramName {
        indices := rs.static_indices_queue[shader]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, shst.active_programs[shader].ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.static_z_width_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(z_widths[0]) * len(z_widths), raw_data(z_widths), gl.STATIC_READ)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.static_z_width_ssbo)
}

init_player_render_data :: proc(gs: ^Game_State, shst: ^ShaderState, rs: ^Render_State) {
    indices_offset := u16(len(rs.vertices))
    for ind in gs.player_geometry.indices {
        append(&rs.static_indices_queue[.Player], ind + indices_offset)
    }
    for v in gs.player_geometry.vertices {
        append(&rs.vertices, v)
    }
    indices := rs.static_indices_queue[.Player]
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, shst.active_programs[.Player].ebo_id)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)

}

bind_vertices :: proc(rs: ^Render_State) {
    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(rs.vertices[0]) * len(rs.vertices), raw_data(rs.vertices), gl.STATIC_DRAW)
}

draw_triangles :: proc(gs: ^Game_State, rs: ^Render_State, shst: ^ShaderState, ps: ^Physics_State, time: f64) {
    //queue_draw_aabb(gs, rs, ps, &rs.transformed_vertices)    

    gl.BindVertexArray(rs.standard_vao)

    c_pos := gs.camera_state.position
    p_pos := gs.player_state.position

    proj_mat := construct_camera_matrix(&gs.camera_state)
    player_mat := construct_player_matrix(&gs.player_state)

    player_pos := glm.vec3({f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)})
    player_trail : [3]glm.vec3 = { gs.player_state.trail[16], gs.player_state.trail[32], gs.player_state.trail[49] }
    crunch_pt : glm.vec3 = gs.player_state.crunch_pt

    use_shader(shst, rs, .Outline)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_lines(rs, shst, .Outline)

    use_shader(shst, rs, .RedOutline)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_lines(rs, shst, .RedOutline)

    use_shader(shst, rs, .Player)
    set_matrix_uniform(shst, "projection", &proj_mat)
    set_matrix_uniform(shst, "transform", &player_mat)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    shader_draw_triangles(rs, shst, .Player)

    use_shader(shst, rs, .Trail)
    set_vec3_uniform(shst, "player_trail_in", 3, &player_trail[0])
    set_vec3_uniform(shst, "player_pos_in", 1, &player_pos)
    set_vec3_uniform(shst, "crunch_pt", 1, &crunch_pt)
    set_float_uniform(shst, "crunch_time", f32(gs.player_state.crunch_time) / 1000)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_triangles(rs, shst, .Trail)
}

