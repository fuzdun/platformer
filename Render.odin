package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

vao, vbo, ebo, pattern_program, outline_program: u32
i_mat :: glm.mat4(1.0)

vertices_queue: [dynamic]Vertex
indices_queue: [dynamic]u16
transform_queue: [dynamic]glm.mat4
indices_counts: [dynamic]int
outline_indices_queue: [dynamic]u16
outline_indices_counts: [dynamic]int

rotation_queue : [dynamic]glm.mat4

init_world :: proc() {
    vertices_queue = make([dynamic]Vertex)
    indices_queue = make([dynamic]u16)
    transform_queue = make([dynamic]glm.mat4)
    indices_counts = make([dynamic]int)
}

current_shape: Shape = .None
indices_offset: u16 = 0
outline_indices_offset: u16 = 0

add_object :: proc(shape: Shape, transform: glm.mat4) {
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
    append(&rotation_queue, i_mat)
}


rotate_transforms :: proc(time: f64) {
    for &rotation in rotation_queue {
        rotation = glm.mat4Rotate({ 0, 1, 0}, f32(time) / 2.0)
    }
}


add_test_objects :: proc() {
    add_object(.InvertedPyramid, glm.mat4Translate({0, 0, 0}))
    add_object(.InvertedPyramid, glm.mat4Translate({0, 1, -1}) * glm.mat4Rotate({1, 0, 0}, 90))
    add_object(.Triangle, glm.mat4Translate({1, 0, 0}))
    add_object(.InvertedPyramid, glm.mat4Translate({-.5, 1, 0}) * glm.mat4Rotate({0, 0, 1}, 180))
}


init_draw :: proc() {
    program_ok : bool
    pattern_program, program_ok = shader_program_from_file("bluevertex.glsl", "bluefrag.glsl")
    if !program_ok {
        fmt.eprintln("Failed to compile glsl")
        return
    }

    outline_program, program_ok = shader_program_from_file("outlinevertex.glsl", "outlinefrag.glsl")
    if !program_ok {
        fmt.eprintln("Failed to compile glsl")
        return
    }

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
}

draw_triangles :: proc(time: f64, wireframe: bool) {
    if wireframe {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    }
    gl.UseProgram(pattern_program)
    gl.BindVertexArray(vao)
    gl.Enable(gl.DEPTH_TEST)

    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := view * proj * offset

    uniforms := gl.get_uniforms_from_program(pattern_program)

    gl.UniformMatrix4fv(uniforms["projection"].location, 1, gl.FALSE, &proj_mat[0, 0])
    gl.Uniform1f(uniforms["i_time"].location, f32(time))

    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices_queue[0]) * len(vertices_queue), raw_data(vertices_queue), gl.STATIC_DRAW)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices_queue[0]) * len(indices_queue), raw_data(indices_queue), gl.STATIC_DRAW)


    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
    indices_index := 0
    for count, i in indices_counts {
        transform := transform_queue[i] * rotation_queue[i]
        gl.UniformMatrix4fv(uniforms["transform"].location, 1, gl.FALSE, &transform[0][0])
        gl.DrawElements(gl.TRIANGLES, i32(count), gl.UNSIGNED_SHORT, rawptr(uintptr(size_of(u16) * indices_index)))
        indices_index += count
    }
    gl.UseProgram(outline_program)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.LineWidth(5)

    uniforms = gl.get_uniforms_from_program(outline_program)
    gl.UniformMatrix4fv(uniforms["projection"].location, 1, gl.FALSE, &proj_mat[0, 0])
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(outline_indices_queue[0]) * len(outline_indices_queue), raw_data(outline_indices_queue), gl.STATIC_DRAW)

    indices_index = 0
    for count, i in outline_indices_counts {
        transform := transform_queue[i] * rotation_queue[i]
        gl.UniformMatrix4fv(uniforms["transform"].location, 1, gl.FALSE, &transform[0][0])
        gl.DrawElements(gl.TRIANGLES, i32(count), gl.UNSIGNED_SHORT, rawptr(uintptr(size_of(u16) * indices_index)))
        indices_index += count
    }
}
