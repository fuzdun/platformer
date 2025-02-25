package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"

I_MAT :: glm.mat4(1.0)

Render_State :: struct {
    transformed_vertices: [dynamic]Vertex,
    front_zs: [dynamic]f32,
    z_dist_ssbo: u32,
    i_queue: [ProgramName][dynamic]u16,
    vbo: u32
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
    rs.transformed_vertices = make([dynamic]Vertex)
    rs.front_zs = make([dynamic]f32)
    for program in ProgramName {
        rs.i_queue[program] = make([dynamic]u16) 
    }
    gl.GenBuffers(1, &rs.z_dist_ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_dist_ssbo)
}

clear_render_queues :: proc(rs: ^Render_State) {
    clear(&rs.transformed_vertices)
    clear(&rs.front_zs)
    for &arr in rs.i_queue {
        clear(&arr)
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    delete(rs.transformed_vertices)
    delete(rs.front_zs)
    for iq in rs.i_queue do delete(iq)
}

init_draw :: proc(rs: ^Render_State, ss: ^ShaderState) {
    init_shaders(ss)

    gl.GenBuffers(1, &rs.vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.vbo)

    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, b_uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

transform_vertices :: proc(gs: ^Game_State, rs: ^Render_State, ps: ^Physics_State) {
    clear_render_queues(rs)
    for lg in gs.level_geometry {
        if .Shape in lg.attributes {
            sd := gs.level_resources[lg.shape]
            indices_offset := u16(len(rs.transformed_vertices))
            for shader in lg.shaders {
                for ind in sd.indices {
                    append(&rs.i_queue[shader], ind + indices_offset)
                }
            }
            min_z := max(f32)
            max_z := min(f32)
            for v in sd.vertices {
                new_pos := v.pos
                new_pos.xyz = transformed_vertex_pos(v, lg.transform)
                min_z = min(new_pos.z, min_z)
                max_z = max(new_pos.z, max_z)
                new_norm := transformed_vertex_normal(v, lg.transform)
                new_v: Vertex = {new_pos, v.uv, v.b_uv, new_norm}
                append(&rs.transformed_vertices, new_v)
            }
            z_diff := max_z - min_z
            for _ in 0..<len(sd.vertices) {
                append(&rs.front_zs, z_diff)
            }
        }
    }
    return
}

queue_draw_player :: proc(gs: Game_State, rs: ^Render_State, out: ^[dynamic]Vertex) {
    indices_offset := u16(len(out))
    sd := gs.player_geometry
    for i in sd.indices {
        append(&rs.i_queue[.Player], i + indices_offset)
    }
    rot := la.quaternion_from_euler_angles(f32(0), f32(0), f32(0), .XYZ)
    p_pos := gs.player_state.position
    p_trns: Transform = {{f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)}, {1, 1, 1}, rot}
    for v in sd.vertices {
        new_pos := v.pos
        new_pos.xyz = transformed_vertex_pos(v, p_trns)
        new_v : Vertex = {new_pos, v.uv, v.b_uv, v.normal}
        append(out, new_v)
    }
}

queue_draw_aabb :: proc(gs: ^Game_State, rs: ^Render_State, ps: ^Physics_State, out: ^[dynamic]Vertex) {
    for pn in ProgramName {
        offset_indices(ps.debug_render_queue.indices[pn][:], u16(len(out)), &rs.i_queue[pn])
    }
    append(out, ..ps.debug_render_queue.vertices[:])
}

draw_triangles :: proc(gs: ^Game_State, rs: ^Render_State, ss: ^ShaderState, ps: ^Physics_State, time: f64) {
    transform_vertices(gs, rs, ps)
    queue_draw_player(gs^, rs, &rs.transformed_vertices)
    queue_draw_aabb(gs, rs, ps, &rs.transformed_vertices)    

    for name, program in ss.active_programs {
        indices := rs.i_queue[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }

    gl.BufferData(gl.ARRAY_BUFFER, size_of(rs.transformed_vertices[0]) * len(rs.transformed_vertices), raw_data(rs.transformed_vertices), gl.STREAM_DRAW)

    c_pos := gs.camera_state.position
    p_pos := gs.player_state.position

    proj_mat := construct_camera_matrix(&gs.camera_state)

    player_pos := glm.vec3({f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)})
    player_trail : [3]glm.vec3 = { gs.player_state.trail[16], gs.player_state.trail[32], gs.player_state.trail[49] }
    crunch_pt : glm.vec3 = gs.player_state.crunch_pt 

    front_zs := make([]f32, len(rs.transformed_vertices)); defer delete(front_zs)
    copy(front_zs, rs.front_zs[:])

    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(front_zs[0]) * len(front_zs), &front_zs[0], gl.DYNAMIC_READ)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.z_dist_ssbo)

    use_shader(ss, .Outline)
    set_vec3_uniform(ss, "player_pos_in", 1, &player_pos)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_lines(rs, ss, .Outline)

    use_shader(ss, .RedOutline)
    set_vec3_uniform(ss, "player_pos_in", 1, &player_pos)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_lines(rs, ss, .RedOutline)

    use_shader(ss, .Player)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    shader_draw_triangles(rs, ss, .Player)

    use_shader(ss, .Trail)
    set_vec3_uniform(ss, "player_pos_in", 1, &player_pos)
    set_vec3_uniform(ss, "player_trail_in", 3, &player_trail[0])
    set_vec3_uniform(ss, "crunch_pt", 1, &crunch_pt)
    set_float_uniform(ss, "crunch_time", f32(gs.player_state.crunch_time) / 1000)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_triangles(rs, ss, .Trail)
}

