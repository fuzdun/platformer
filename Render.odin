package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

vao, vbo, ebo : u32
i_mat :: glm.mat4(1.0)

vertices_queue: [dynamic]Vertex
indices_queue: [dynamic]u16
transform_queue: [dynamic]glm.mat4
indices_counts: [dynamic]int
outline_indices_queue: [dynamic]u16
outline_indices_counts: [dynamic]int

offset_queue : [dynamic]glm.mat4

current_shape: Shape = .None
indices_offset: u16 = 0
outline_indices_offset: u16 = 0

add_object_to_render_buffers :: proc(shape: Shape, transform: glm.mat4) {
    if current_shape != shape {
        indices_offset = u16(len(vertices_queue))
        append(&vertices_queue, ..SHAPE_DATA[shape].vertices)
        current_shape = shape
    }
    indices := SHAPE_DATA[shape].indices
    outline_indices := SHAPE_DATA[shape].outline_indices
    for i in indices {
        append(&indices_queue, i + indices_offset)
    }
    for i in outline_indices {
        append(&outline_indices_queue, i + indices_offset)
    }
    append(&indices_counts, len(indices))
    append(&outline_indices_counts, len(outline_indices))
    append(&transform_queue, transform)
    append(&offset_queue, i_mat)
}


rotate_transforms :: proc(time: f64) {
    for &offset in offset_queue {
        offset = glm.mat4Rotate({ 0, 1, 0}, f32(time) / 2.0)
    }
}


add_test_objects :: proc() {
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({0, 0, 0}))
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({0, 1, -1}) * glm.mat4Rotate({1, 0, 0}, 90))
    add_object_to_render_buffers(.Triangle, glm.mat4Translate({1, 0, 0}))
    add_object_to_render_buffers(.InvertedPyramid, glm.mat4Translate({-.5, 1, 0}) * glm.mat4Rotate({0, 0, 1}, 180))
}


// Further design notes:
// - abstract sorting data into various buffers based on shader type,
//   then execute one draw sequence per shader
// - should compute per-object transformations and apply to vertices
//   before passing to GPU, because I need the coords anyway for 
//   constructing physics world


init_draw :: proc() {
    init_shaders()

    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao)

    gl.GenBuffers(1, &vbo);
    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.DEPTH_TEST)
}

draw_triangles :: proc(time: f64) {
    gl.BindVertexArray(vao)

    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := view * proj * offset

    use_shader(.Pattern)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

    set_matrix_uniform("projection", &proj_mat)
    set_float_uniform("i_time", f32(time))

    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices_queue[0]) * len(vertices_queue), raw_data(vertices_queue), gl.STATIC_DRAW)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices_queue[0]) * len(indices_queue), raw_data(indices_queue), gl.STATIC_DRAW)

    indices_index := 0
    for count, i in indices_counts {
        transform := transform_queue[i] * offset_queue[i]
        set_matrix_uniform("transform", &transform)
        gl.DrawElements(gl.TRIANGLES, i32(count), gl.UNSIGNED_SHORT, rawptr(uintptr(size_of(u16) * indices_index)))
        indices_index += count
    }

    use_shader(.Outline)
    set_matrix_uniform("projection", &proj_mat)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.LineWidth(5)

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(outline_indices_queue[0]) * len(outline_indices_queue), raw_data(outline_indices_queue), gl.STATIC_DRAW)
    indices_index = 0
    for count, i in outline_indices_counts {
        transform := transform_queue[i] * offset_queue[i]
        set_matrix_uniform("transform", &transform)
        gl.DrawElements(gl.TRIANGLES, i32(count), gl.UNSIGNED_SHORT, rawptr(uintptr(size_of(u16) * indices_index)))
        indices_index += count
    }
}
