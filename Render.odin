package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

i_mat :: glm.mat4(1.0)

vertices_queue: [dynamic]Vertex
indices_queues: [ProgramName][dynamic]u16
transform_queue: [dynamic]glm.mat4
transform_counts: [dynamic]int
offset_queue: [dynamic]glm.mat4

indices_offset: u16 = 0

init_render_buffers :: proc() {
    for program in ProgramName {
        indices_queues[program] = make([dynamic]u16) 
    }
    vertices_queue = make([dynamic]Vertex)
    transform_queue = make([dynamic]glm.mat4)
    transform_counts = make([dynamic]int)
    offset_queue = make([dynamic]glm.mat4)
}

free_render_buffers :: proc() {
    delete(vertices_queue)
    for iq in indices_queues do delete(iq)
    delete(transform_queue)
    delete(transform_counts)
    delete(offset_queue)
}

add_object_to_render_buffers :: proc(shape: Shape, transform: glm.mat4) {
    indices_offset = u16(len(vertices_queue))
    append(&vertices_queue, ..SHAPE_DATA[shape].vertices)
    for indices_list in SHAPE_DATA[shape].indices_lists {
        shifted_indices := make([dynamic]u16); defer delete(shifted_indices)
        offset_indices(indices_list.indices, indices_offset, &shifted_indices)
        iq_idx := int(indices_list.shader)
        append(&indices_queues[indices_list.shader], ..shifted_indices[:])
    }
    append(&transform_counts, len(SHAPE_DATA[shape].vertices))
    append(&transform_queue, transform)
    append(&offset_queue, i_mat)
}

vao, vbo : u32

init_draw :: proc() {
    init_shaders()

    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao)

    gl.GenBuffers(1, &vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.DEPTH_TEST)
}

load_level :: proc() {
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({0, 0, 0}))
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({0, 2, -1}) * glm.mat4Rotate({1, 0, 0}, 90))
    add_object_to_render_buffers(.Triangle, glm.mat4Translate({1, 0, 0}))
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({-.5, 1, 0}) * glm.mat4Rotate({0, 0, 1}, 180))


    for name, program in active_programs {
        indices := indices_queues[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }

}

draw_triangles :: proc(time: f64) {
    gl.BindVertexArray(vao)

    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := view * proj * offset

    transformed_vertices := make([dynamic]Vertex); defer delete(transformed_vertices)
    transform_vertices(vertices_queue, transform_queue, transform_counts, &transformed_vertices)

    use_shader(.Pattern)
    set_matrix_uniform("projection", &proj_mat)
    set_float_uniform("i_time", f32(time) / 1000)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

    gl.BufferData(gl.ARRAY_BUFFER, size_of(transformed_vertices[0]) * len(transformed_vertices), raw_data(transformed_vertices), gl.STREAM_DRAW)
    indices_queue := indices_queues[.Pattern]
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, active_programs[.Pattern].ebo_id)
    gl.DrawElements(gl.TRIANGLES, i32(len(indices_queue)), gl.UNSIGNED_SHORT, nil)

    use_shader(.Outline)
    set_matrix_uniform("projection", &proj_mat)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.LineWidth(5)
    indices_queue = indices_queues[.Outline]

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, active_programs[.Outline].ebo_id)
    gl.DrawElements(gl.TRIANGLES, i32(len(indices_queue)), gl.UNSIGNED_SHORT, nil)
}
