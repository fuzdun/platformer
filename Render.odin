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
SHAPE_NAMES :: [?]string {"basic_cube", "basic_cube2"}

Renderables :: map[ProgramName]Shape_Renderables
Shape_Renderables :: map[string][dynamic]Transform

Render_State :: struct {
    vertices: [dynamic]Vertex,
    static_z_width_ssbo: u32,
    matrices: [dynamic]glm.mat4,
    matrices_ssbo: u32,
    static_indices_queue: [ProgramName][dynamic]u32,
    standard_vao: u32,
    standard_vbo: u32,
    obj_poss: [dynamic]glm.vec3,
    obj_poss_ssbo: u32,
    renderables: Renderables
    //particle_vao: u32,
    //particle_vbo: u32,
}

load_geometry_data :: proc(gs: ^Game_State, ps: ^Physics_State) {
    for name in SHAPE_NAMES {
        if ok := load_blender_model(name, gs, ps); ok {
            fmt.println("loaded", name) 
        }
    }
}

init_render_buffers :: proc(gs: ^Game_State, rs: ^Render_State) {
    add_player_sphere_data(gs)
    rs.vertices = make([dynamic]Vertex)
    rs.matrices = make([dynamic]glm.mat4)
    rs.obj_poss = make([dynamic]glm.vec3)
    for program in ProgramName {
        rs.static_indices_queue[program] = make([dynamic]u32) 
    }
    rs.renderables = make(Renderables)
    for shader in ProgramName {
        shape_renderables := make(map[string][dynamic]Transform)
        for shape in SHAPE_NAMES {
            shape_renderables[shape] = make([dynamic]Transform)
        }
        rs.renderables[shader] = shape_renderables
    }
    fmt.println(rs.renderables)
}

clear_render_queues :: proc(rs: ^Render_State) {
    clear(&rs.vertices)
    for &arr in rs.static_indices_queue {
        clear(&arr)
    }
    for shader in ProgramName {
        for shape in SHAPE_NAMES {
            clear(&rs.renderables[shader][shape])
        }
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    delete(rs.vertices)
    delete(rs.matrices)
    delete(rs.obj_poss)
    for iq in rs.static_indices_queue do delete(iq)
    for shader in ProgramName {
        for shape in SHAPE_NAMES {
            delete(rs.renderables[shader][shape])
        }
        delete(rs.renderables[shader])
    }
    delete(rs.renderables)
}

init_draw :: proc(rs: ^Render_State, ss: ^ShaderState) -> bool {
    if !init_shaders(ss) {
        fmt.eprintln("shader init failed")
        return false
    }

    gl.GenBuffers(1, &rs.static_z_width_ssbo)
    gl.GenBuffers(1, &rs.matrices_ssbo)
    gl.GenBuffers(1, &rs.obj_poss_ssbo)

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

    //gl.GenVertexArrays(1, &rs.particle_vao)
    //gl.GenBuffers(1, &rs.particle_vbo)
    //gl.BindVertexArray(rs.particle_vao)
    //gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    //gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, pos))
    //gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, uv))
    //gl.EnableVertexAttribArray(0)
    //gl.EnableVertexAttribArray(1)
    //
    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    return true
}

init_level_render_data :: proc(gs: ^Game_State, shst: ^ShaderState, rs: ^Render_State) {
    z_widths := make([dynamic]f32); defer delete(z_widths)
    for &lg, lg_idx in gs.level_geometry {
        //fmt.println("===========")
        sd := gs.level_resources[lg.shape]
        if !(.Angular_Velocity in lg.attributes) {
            trns_mat := trans_to_mat4(lg.transform)
            indices_offset := u32(len(rs.vertices))
            lg.gl_vertex_index = indices_offset
            for shader in lg.shaders {
                for ind in sd.indices {
                    append(&rs.static_indices_queue[shader], u32(ind) + u32(indices_offset))
                }
            }
            min_z := max(f32)
            max_z := min(f32)
            for v in sd.vertices {
                tv := transformed_vertex(v, lg.transform)
                min_z = min(tv.pos.z, min_z) 
                max_z = max(tv.pos.z, max_z)
                append(&rs.vertices, tv)
                append(&rs.obj_poss, lg.transform.position)
            }
            z_diff := max_z - min_z
            for _ in 0..<len(sd.vertices) {
                append(&z_widths, z_diff)
            }
            //append(&rs.matrices, trns_mat)
        } 
    }
    for shader in ProgramName {
        indices := rs.static_indices_queue[shader]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, shst.active_programs[shader].ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.static_z_width_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(z_widths[0]) * len(z_widths), raw_data(z_widths), gl.STATIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.static_z_width_ssbo)

    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.matrices_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.matrices[0]) * len(rs.matrices), raw_data(rs.matrices), gl.STATIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.matrices_ssbo)

    //sd := gs.level_resources["basic_cube2"]
    //gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, shst.active_programs[.Simple].ebo_id)
    //gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(sd.indices[0]) * len(sd.indices), raw_data(sd.indices), gl.STATIC_DRAW)

    //gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    //gl.BufferData(gl.ARRAY_BUFFER, size_of(sd.vertices[0]) * len(sd.vertices), raw_data(sd.vertices), gl.STATIC_DRAW)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.obj_poss_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.obj_poss[0]) * len(rs.obj_poss), raw_data(rs.obj_poss), gl.STATIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, rs.obj_poss_ssbo)
}

init_player_render_data :: proc(gs: ^Game_State, shst: ^ShaderState, rs: ^Render_State) {
    indices_offset := len(rs.vertices)
    for ind in gs.player_geometry.indices {
        append(&rs.static_indices_queue[.Player], u32(ind) + u32(indices_offset))
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

update_vertices :: proc(gs: ^Game_State, rs: ^Render_State) {
    if len(gs.dirty_entities) > 0 {
        for lg_idx in gs.dirty_entities {
            lg := gs.level_geometry[lg_idx]
            trns := lg.transform
            vertices := gs.level_resources[lg.shape].vertices
            new_vertices := make([]Vertex, len(vertices)); defer delete(new_vertices)
            for v, vi in gs.level_resources[lg.shape].vertices {
                new_pos := la.quaternion128_mul_vector3(trns.rotation, trns.scale * v.pos) + trns.position
                new_vertex: Vertex = {new_pos, v.uv, v.b_uv, v.normal}
                idx := lg.gl_vertex_index + u32(vi)
                rs.vertices[lg.gl_vertex_index + u32(vi)] = new_vertex
                new_vertices[vi] = new_vertex
            }
            gl.BindVertexArray(rs.standard_vao)
            gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
            gl.BufferSubData(gl.ARRAY_BUFFER, int(lg.gl_vertex_index * size_of(Vertex)), size_of(Vertex) * len(new_vertices), rawptr(&new_vertices[0]))
        }
    }
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

    //use_shader(shst, rs, .Outline)
    //set_matrix_uniform(shst, "projection", &proj_mat)
    //shader_draw_lines(rs, shst, .Outline)
    //
    //use_shader(shst, rs, .RedOutline)
    //set_matrix_uniform(shst, "projection", &proj_mat)
    //shader_draw_lines(rs, shst, .RedOutline)
    //
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
    
    //cube_sd := gs.level_resources["basic_cube2"]
    //use_shader(shst, rs, .Simple)
    //set_matrix_uniform(shst, "projection", &proj_mat)
    //gl.DrawElementsInstanced(gl.TRIANGLES, i32(len(cube_sd.indices)), gl.UNSIGNED_INT, nil, i32(len(gs.level_geometry)))

}

trans_to_mat4 :: proc(trns: Transform) -> glm.mat4 {
    off := glm.mat4Translate(trns.position)
    rot := glm.mat4FromQuat(trns.rotation)
    scale := glm.mat4Scale(trns.scale)
    return off * rot * scale
}

