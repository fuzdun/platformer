package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"

I_MAT :: glm.mat4(1.0)

RenderState :: struct {
    v_queue: [dynamic]Vertex,
    i_queue: [ProgramName][dynamic]u16,
    vbo: u32
}

init_render_buffers :: proc(rs: ^RenderState) {
    add_sphere_data()
    for program in ProgramName {
        rs.i_queue[program] = make([dynamic]u16) 
    }
    rs.v_queue = make([dynamic]Vertex)
}

clear_indices_queues :: proc(rs: ^RenderState) {
    for &arr in rs.i_queue {
        clear(&arr)
    }
}

free_render_buffers :: proc(rs: ^RenderState) {
    delete(rs.v_queue)
    for iq in rs.i_queue do delete(iq)
}

init_draw :: proc(rs: ^RenderState, ss: ^ShaderState) {
    init_shaders(ss)

    gl.GenBuffers(1, &rs.vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.vbo)

    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.DEPTH_TEST)
}

get_vertices_update_indices :: proc(gs: ^GameState, rs: ^RenderState, out: ^[dynamic]Vertex) {
    scale_identity : Scale = {1, 1, 1}
    for lg in gs.level_geometry {
        indices_offset := u16(len(out))
        sd := SHAPE_DATA[lg.shape]
        vertices := sd.vertices
        for indices_list in sd.indices_lists {
            if indices_list.shader in lg.shaders {
                offset_indices(indices_list.indices[:], indices_offset, &rs.i_queue[indices_list.shader])
            }
        }
        scale := .Scale in lg.attributes ? lg.scale : {1, 1, 1}
        rotation := lg.rotation
        transform_vertices(vertices, lg.position, scale, lg.rotation, out)
    }
    return
}

queue_draw_player :: proc(ps: Player_State, rs: ^RenderState, out: ^[dynamic]Vertex) {
    indices_offset := u16(len(out))
    sd := SHAPE_DATA[.Sphere]
    rot := la.quaternion_from_euler_angles(f32(0), f32(0), f32(0), .XYZ)
    p_pos := ps.position
    transform_vertices(sd.vertices, {f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)}, {1, 1, 1}, rot, out)
    for indices_list in sd.indices_lists {
        offset_indices(indices_list.indices[:], indices_offset, &rs.i_queue[indices_list.shader])
    }
}

queue_draw_aabb :: proc(gs: ^GameState, rs: ^RenderState, ps: ^Physics_State, out: ^[dynamic]Vertex) {
    for obj in ps.objects {
        shader : ProgramName = obj.collided ? .RedOutline : .Outline
        indices_offset := u16(len(out))
        lg := gs.level_geometry[obj.id]
        vertices := aabb_vertices(obj)
        append(out, ..vertices[:])
        offset_indices(AABB_INDICES, indices_offset, &rs.i_queue[shader])
    }
}

draw_triangles :: proc(gs: ^GameState, rs: ^RenderState, ss: ^ShaderState, ps: ^Physics_State, time: f64) {
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    clear_indices_queues(rs)
    transformed_vertices := make([dynamic]Vertex)
    defer delete(transformed_vertices)
    get_vertices_update_indices(gs, rs, &transformed_vertices)
    queue_draw_player(gs.player_state, rs, &transformed_vertices)

    if gs.input_state.c_pressed {
        queue_draw_aabb(gs, rs, ps, &transformed_vertices)    
    }

    for name, program in ss.active_programs {
        indices := rs.i_queue[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }

    gl.BufferData(gl.ARRAY_BUFFER, size_of(transformed_vertices[0]) * len(transformed_vertices), raw_data(transformed_vertices), gl.STREAM_DRAW)

    c_pos := gs.camera_state.position
    p_pos := gs.player_state.position
    rot := glm.mat4LookAt({0, 0, 0}, {f32(p_pos.x - c_pos.x), f32(p_pos.y - c_pos.y), f32(p_pos.z - c_pos.z)}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(-c_pos.x), f32(-c_pos.y), f32(-c_pos.z)})

    proj_mat := proj * rot * offset
    player_pos := glm.vec3({f32(p_pos.x), f32(p_pos.y), f32(p_pos.z)})
    player_trail : [3]glm.vec3 = { gs.player_state.trail[16], gs.player_state.trail[32], gs.player_state.trail[49] }

    use_shader(ss, .Player)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    shader_draw_triangles(rs, ss, .Player)

    use_shader(ss, .Reactive)
    set_vec3_uniform(ss, "player_pos_in", 1, &player_pos)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_triangles(rs, ss, .Reactive)

    use_shader(ss, .Trail)
    set_vec3_uniform(ss, "player_pos_in", 1, &player_pos)
    set_vec3_uniform(ss, "player_trail_in", 3, &player_trail[0])
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_triangles(rs, ss, .Trail)

    use_shader(ss, .Pattern)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    shader_draw_triangles(rs, ss, .Pattern)

    use_shader(ss, .New)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    shader_draw_triangles(rs, ss, .New)

    use_shader(ss, .Outline)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_lines(rs, ss, .Outline)

    use_shader(ss, .RedOutline)
    set_matrix_uniform(ss, "projection", &proj_mat)
    shader_draw_lines(rs, ss, .RedOutline)
}

