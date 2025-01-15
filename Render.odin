package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

vao, vbo, ebo, program: u32
i_mat :: glm.mat4(1.0)

shape_queue : []Shape = {
    .InvertedPyramid,
    .InvertedPyramid,
    .InvertedPyramid }

transform_queue : []glm.mat4 = {
    i_mat * glm.mat4Translate({0, 0, 0}),
    i_mat * glm.mat4Translate({0, 1, -1}) * glm.mat4Rotate({1, 0, 0}, 90),
    i_mat * glm.mat4Translate({-.5, 1, 0}) * glm.mat4Rotate({0, 0, 1}, 180)
}

rotation_queue : []glm.mat4 = {
    i_mat,
    i_mat,
    i_mat
}

rotate_transforms :: proc(time: f64) {
    for &rotation in rotation_queue {
        rotation = glm.mat4Rotate({ 0, 1, 0}, f32(time) / 2.0)
    }
}


init_draw :: proc() {
    program_result, program_ok := shader_program_from_file("bluevertex.glsl", "bluefrag.glsl")
    if !program_ok {
        fmt.eprintln("Failed to compile glsl")
        return
    }
    program = program_result

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

draw_triangles :: proc(time: f64) {
    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    gl.Enable(gl.DEPTH_TEST)

    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(px), f32(py), f32(pz)})

    proj_mat := view * proj * offset

    uniforms := gl.get_uniforms_from_program(program)

    for shape, i in shape_queue {
        sd := SHAPE_DATA[shape]
        transform := transform_queue[i] * rotation_queue[i]

        gl.BufferData(gl.ARRAY_BUFFER, size_of(sd.vertices[0]) * len(sd.vertices), raw_data(sd.vertices), gl.STATIC_DRAW)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(sd.indices[0]) * len(sd.indices), raw_data(sd.indices), gl.STATIC_DRAW)

        gl.Uniform1f(uniforms["i_time"].location, f32(time))
        gl.UniformMatrix4fv(uniforms["transform"].location, 1, gl.FALSE, &transform[0, 0])
        gl.UniformMatrix4fv(uniforms["projection"].location, 1, gl.FALSE, &proj_mat[0, 0])

        gl.DrawElements(gl.TRIANGLES, i32(len(sd.indices)), gl.UNSIGNED_SHORT, nil)
    }


}
