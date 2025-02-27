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
    //transforms: [dynamic]Transform,
    //transformed_vertices: [dynamic]Vertex,
    static_vertices: [dynamic]Vertex,
    player_ebo: u32,
    standard_ebo: u32,
    front_zs: [dynamic]f32,
    z_dist_ssbo: u32,
    //transform_ssbo: u32,
    particle_offsets_ssbo: u32,
    static_indices_queue: [ProgramName][dynamic]u16,
    standard_vao: u32,
    particle_vao: u32,
    standard_vbo: u32,
    particle_vbo: u32
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
    //rs.transformed_vertices = make([dynamic]Vertex)
    rs.front_zs = make([dynamic]f32)
    //rs.transforms = make([dynamic]Transform)
    rs.static_vertices = make([dynamic]Vertex)
    for program in ProgramName {
        rs.static_indices_queue[program] = make([dynamic]u16) 
    }
}

clear_render_queues :: proc(rs: ^Render_State) {
    //clear(&rs.transformed_vertices)
    clear(&rs.front_zs)
    clear(&rs.static_vertices)
    //clear(&rs.transforms)
    for &arr in rs.static_indices_queue {
        clear(&arr)
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    //delete(rs.transformed_vertices)
    delete(rs.static_vertices)
    delete(rs.front_zs)
    //delete(rs.transforms)
    for iq in rs.static_indices_queue do delete(iq)
}

init_draw :: proc(rs: ^Render_State, ss: ^ShaderState) {
    init_shaders(ss)

    //gl.GenBuffers(1, &rs.z_dist_ssbo)
    //gl.GenBuffers(1, &rs.transform_ssbo)
    gl.GenBuffers(1, &rs.standard_ebo)

    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenBuffers(1, &rs.standard_vbo)
    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, b_uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)

    gl.GenVertexArrays(1, &rs.particle_vao)
    gl.GenBuffers(1, &rs.particle_vbo)
    gl.BindVertexArray(rs.particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Particle_Vertex), offset_of(Particle_Vertex, uv))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

init_level_render_data :: proc(gs: ^Game_State, rs: ^Render_State) {
    for lg in gs.level_geometry {
        sd := gs.level_resources[lg.shape]
        if !(.Angular_Velocity in lg.attributes) {
            indices_offset := u16(len(rs.static_vertices))
            for shader in lg.shaders {
                for ind in sd.indices {
                    append(&rs.static_indices_queue[shader], ind + indices_offset)
                }
            }
            for v in sd.vertices {
                append(&rs.static_vertices, transformed_vertex(v, lg.transform))
            }
        } 
    }
}
 
//packed_data :: struct{
//    transform: Transform,
//    vertex_pos: glm.vec3,
//    vertex_norm: glm.vec3
//}

//transform_vertices :: proc(gs: ^Game_State, rs: ^Render_State, ps: ^Physics_State) {
    //fmt.println(size_of(packed_data))
    //start_time := tm.now()
    //clear_render_queues(rs)
    //pd_arr := make([dynamic]packed_data); defer delete(pd_arr)
    //for lg in gs.level_geometry {
    //    if .Shape in lg.attributes {
    //        sd := gs.level_resources[lg.shape]
    //        indices_offset := u16(len(rs.transformed_vertices))
    //        for shader in lg.shaders {
    //            for ind in sd.indices {
    //                append(&rs.i_queue[shader], ind + indices_offset)
    //            }
    //        }
    //        min_z := max(f32)
    //        max_z := min(f32)
    //        for v in sd.vertices {
                //append(&rs.transforms, lg.transform)
                //pd: packed_data
                //pd.transform = lg.transform
                //pd.vertex_pos = v.pos.xyz
                //pd.vertex_norm = v.normal
                //append(&pd_arr, pd)
                //new_pos := v.pos
                //new_pos.xyz = transformed_vertex_pos(v, lg.transform)
                //min_z = min(new_pos.z, min_z)
                //max_z = max(new_pos.z, max_z)
                //new_norm := transformed_vertex_normal(v, lg.transform)
                //new_v: Vertex = {new_pos, v.uv, v.b_uv, new_norm}
                //append(&rs.transformed_vertices, v)
            //}
            //z_diff := max_z - min_z
            //for _ in 0..<len(sd.vertices) {
            //    append(&rs.front_zs, z_diff)
            //}
        //}
    //}
    //fmt.println("transform vertices time:", tm.since(start_time))
    //fmt.println("transform vertices time:")
    //return
//}

//get_player_mesh_data :: proc(gs: Game_State, rs: ^Render_State )

//queue_draw_aabb :: proc(gs: ^Game_State, rs: ^Render_State, ps: ^Physics_State, out: ^[dynamic]Vertex) {
//    for pn in ProgramName {
//        offset_indices(ps.debug_render_queue.indices[pn][:], u16(len(out)), &rs.i_queue[pn])
//    }
//    append(out, ..ps.debug_render_queue.vertices[:])
//}

draw_triangles :: proc(gs: ^Game_State, rs: ^Render_State, shst: ^ShaderState, ps: ^Physics_State, time: f64) {
    //transform_vertices(gs, rs, ps)

    //queue_draw_player(gs^, rs, &rs.transformed_vertices)
    //queue_draw_aabb(gs, rs, ps, &rs.transformed_vertices)    

    gl.BindVertexArray(rs.standard_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(rs.static_vertices[0]) * len(rs.static_vertices), raw_data(rs.static_vertices), gl.STATIC_DRAW)

    c_pos := gs.camera_state.position
    p_pos := gs.player_state.position

    proj_mat := construct_camera_matrix(&gs.camera_state)

    player_pos := glm.vec3({f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)})
    player_trail : [3]glm.vec3 = { gs.player_state.trail[16], gs.player_state.trail[32], gs.player_state.trail[49] }
    crunch_pt : glm.vec3 = gs.player_state.crunch_pt

    //gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_dist_ssbo)
    //gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.front_zs[0]) * len(rs.front_zs), raw_data(rs.front_zs), gl.STATIC_READ)
    //gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.z_dist_ssbo)
    //
    //gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transform_ssbo)

    use_shader(shst, rs, .Outline)
    set_vec3_uniform(shst, "player_pos_in", 1, &player_pos)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_lines(rs, shst, .Outline, i32(len(rs.static_indices_queue[.Outline])))

    use_shader(shst, rs, .RedOutline)
    set_vec3_uniform(shst, "player_pos_in", 1, &player_pos)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_lines(rs, shst, .RedOutline, i32(len(rs.static_indices_queue[.RedOutline])))

    use_shader(shst, rs, .Trail)
    //fmt.println(rs.static_indices_queue[.Trail])
    set_vec3_uniform(shst, "player_pos_in", 1, &player_pos)
    set_vec3_uniform(shst, "player_trail_in", 3, &player_trail[0])
    set_vec3_uniform(shst, "crunch_pt", 1, &crunch_pt)
    set_float_uniform(shst, "crunch_time", f32(gs.player_state.crunch_time) / 1000)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    set_matrix_uniform(shst, "projection", &proj_mat)
    shader_draw_triangles(rs, shst, .Trail, i32(len(rs.static_indices_queue[.Trail])))

    //rot := la.quaternion_from_euler_angles(f32(0), f32(0), f32(0), .XYZ)
    //p_trns: Transform = {player_pos, {1, 1, 1}, rot}
    vertices := gs.player_geometry.vertices
    indices := gs.player_geometry.indices
    //fmt.println(indices)
    player_mat := construct_player_matrix(&gs.player_state)
    shst.loaded_program = shst.active_programs[.Player].id
    gl.UseProgram(shst.loaded_program)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    set_matrix_uniform(shst, "projection", &proj_mat)
    set_matrix_uniform(shst, "transform", &player_mat)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    gl.PolygonMode(gl.FRONT, gl.FILL)
    shader_draw_triangles(rs, shst, .Player, i32(len(indices)))

    //for lg in gs.level_geometry {
    //    indices := rs.i_queue[.Trail]
    //    gl.BufferData(gl.ARRAY_BUFFER, size_of(rs.transformed_vertices[0]) * 3, raw_data(rs.transformed_vertices), gl.STREAM_DRAW)
    //    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * 3, raw_data(indices), gl.DYNAMIC_DRAW)
    //    set_matrix_uniform(shst, "projection", &proj_mat)
    //    shader_draw_triangles(rs, shst, .Trail)
    //}
}

