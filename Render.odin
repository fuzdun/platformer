package main

import "core:fmt"
import "core:math"
import rnd "core:math/rand"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:os"

I_MAT :: glm.mat4(1.0)

RenderState :: struct {
    v_queue: [dynamic]Vertex,
    i_queue: [ProgramName][dynamic]u16,
    t_queue: [dynamic]glm.mat4,
    t_counts: [dynamic]int,
    vbo: u32
}

//vertices_queue: [dynamic]Vertex
//indices_queues: [ProgramName][dynamic]u16
//transform_queue: [dynamic]glm.mat4
//transform_counts: [dynamic]int

//vbo : u32

init_render_buffers :: proc(rs: ^RenderState) {
    for program in ProgramName {
        rs.i_queue[program] = make([dynamic]u16) 
    }
    rs.v_queue = make([dynamic]Vertex)
    rs.t_queue = make([dynamic]glm.mat4)
    rs.t_counts = make([dynamic]int)
}

free_render_buffers :: proc(rs: ^RenderState) {
    delete(rs.v_queue)
    for iq in rs.i_queue do delete(iq)
    delete(rs.t_queue)
    delete(rs.t_counts)
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

add_object_to_render_buffers :: proc(rs: ^RenderState, shape: Shape, transform: glm.mat4) {
    indices_offset := u16(len(rs.v_queue))
    append(&rs.v_queue, ..SHAPE_DATA[shape].vertices)
    for indices_list in SHAPE_DATA[shape].indices_lists {
        shifted_indices := make([dynamic]u16); defer delete(shifted_indices)
        offset_indices(indices_list.indices[:], indices_offset, &shifted_indices)
        iq_idx := int(indices_list.shader)
        append(&rs.i_queue[indices_list.shader], ..shifted_indices[:])
    }

    // should combine count and transform into single struct ?

    append(&rs.t_counts, len(SHAPE_DATA[shape].vertices))
    append(&rs.t_queue, transform)
}

load_level :: proc(rs: ^RenderState, ss: ShaderState) {
    for _ in 0..<10000 {
        shapes : []Shape = { .Cube, .InvertedPyramid }
        s := rnd.choice(shapes)
        x := rnd.float32_range(-20, 20)
        y := rnd.float32_range(-20, 20)
        z := rnd.float32_range(-20, 20)
        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)
        add_object_to_render_buffers(
            rs,
            s,
            glm.mat4Translate({x, y, z}) *
            glm.mat4Rotate({1, 0, 0}, rx) *
            glm.mat4Rotate({0, 1, 0}, ry) *
            glm.mat4Rotate({0, 0, 1}, rz)
        )
    }
    for name, program in ss.active_programs {
        indices := rs.i_queue[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }
}


draw_triangles :: proc(rs: ^RenderState, ss: ^ShaderState, time: f64) {
    transformed_vertices := make([dynamic]Vertex); defer delete(transformed_vertices)
    transform_vertices(rs.v_queue[:], rs.t_queue[:], rs.t_counts[:], &transformed_vertices)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(transformed_vertices[0]) * len(transformed_vertices), raw_data(transformed_vertices), gl.STREAM_DRAW)

    rot := glm.mat4Rotate({1, 0, 0}, f32(crx)) * glm.mat4Rotate({ 0, 1, 0 }, f32(cry))
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := proj * rot * offset

    use_shader(ss, .Pattern)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .Pattern)

    use_shader(ss, .New)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .New)

    use_shader(ss, .Outline)
    set_matrix_uniform(ss, "projection", &proj_mat)
    draw_shader(rs, ss, .Outline)

}
