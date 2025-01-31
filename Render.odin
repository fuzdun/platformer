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

get_vertices_update_indices :: proc(gs: ^GameState, rs: ^RenderState) -> (out: [dynamic]Vertex){
    using gs.ecs
    out = make([dynamic]Vertex)
    ents := entities_with(&gs.ecs, {.Shape, .Transform, .ActiveShaders})
    defer delete(ents)
    for e in ents {
        shape := get_shape(&gs.ecs, e) or_else nil
        transform := get_transform(&gs.ecs, e) or_else nil
        active_shaders := get_shaders(&gs.ecs, e) or_else nil
        indices_offset := u16(len(out))
        sd := SHAPE_DATA[shape^]
        vertices := sd.vertices
        for indices_list in sd.indices_lists {
            if indices_list.shader in active_shaders^ {
                shifted_indices := offset_indices(indices_list.indices[:], indices_offset)
                defer delete(shifted_indices)
                iq_idx := int(indices_list.shader)
                append(&rs.i_queue[indices_list.shader], ..shifted_indices[:])
            }
        }
        transformed_vertices := transform_vertices(vertices, transform^)
        defer delete(transformed_vertices)
        append(&out, ..transformed_vertices)
    }
    return
}

queue_draw_player :: proc(rs: ^RenderState, out: ^[dynamic]Vertex) {
    indices_offset := u16(len(out))
    sd := SHAPE_DATA[.Sphere]
    p_trans := glm.mat4Translate({f32(-px), f32(-py), f32(-pz)})
    transformed_vertices := transform_vertices(sd.vertices, p_trans)
    defer delete(transformed_vertices)
    append(out, ..transformed_vertices) 
    for indices_list in sd.indices_lists {
        shifted_indices := offset_indices(indices_list.indices[:], indices_offset)
        defer delete(shifted_indices)
        append(&rs.i_queue[indices_list.shader], ..shifted_indices[:])
    }
}


draw_triangles :: proc(gs: ^GameState, rs: ^RenderState, ss: ^ShaderState, time: f64) {
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    clear_indices_queues(rs)
    transformed_vertices := get_vertices_update_indices(gs, rs)
    defer delete(transformed_vertices)
    queue_draw_player(rs, &transformed_vertices)
    for name, program in ss.active_programs {
        indices := rs.i_queue[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }
    gl.BufferData(gl.ARRAY_BUFFER, size_of(transformed_vertices[0]) * len(transformed_vertices), raw_data(transformed_vertices), gl.STREAM_DRAW)

    rot := glm.mat4LookAt({0, 0, 0}, {f32(cx - px), f32(cy - py), f32(cz - pz)}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := proj * rot * offset

    use_shader(ss, .Player)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .Player)

    use_shader(ss, .Reactive)
    player_pos := glm.vec3({f32(-px), f32(-py), f32(-pz)})
    set_vec3_uniform(ss, "player_pos_in", &player_pos)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    set_matrix_uniform(ss, "projection", &proj_mat)
    draw_shader(rs, ss, .Reactive)

    use_shader(ss, .Trail)
    set_vec3_uniform(ss, "player_pos_in", &player_pos)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    set_matrix_uniform(ss, "projection", &proj_mat)
    draw_shader(rs, ss, .Trail)

    use_shader(ss, .Pattern)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .Pattern)

    use_shader(ss, .New)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .New)


    //use_shader(ss, .Outline)
    //set_matrix_uniform(ss, "projection", &proj_mat)
    //draw_shader(rs, ss, .Outline)

}

draw_sphere :: proc(gs: ^GameState, rs: ^RenderState){

}

