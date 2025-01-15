package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

Shape :: enum{Triangle2D}

SHAPE_VERTICES :: [Shape][]glm.vec3{
    .Triangle2D = {
        {-0.5, -0.5, 0},
        {0.5, -0.5, 0},
        {0, 0.5, 0}
    }
}

shader_program_from_file :: proc(vertex_filename, fragment_filename: string) -> (u32, bool) {
    dir := "shaders/"
    vertex_string, vertex_ok := os.read_entire_file(str.concatenate({dir, vertex_filename}))
    if !vertex_ok {
        fmt.println("failed to read vertex shader file")
        return 0, false
    }
    fragment_string, fragment_ok := os.read_entire_file(str.concatenate({dir, fragment_filename}))
    if !fragment_ok {
        fmt.println("failed to read fragment shader file")
        return 0, false
    }
    return gl.load_shaders_source(string(vertex_string), string(fragment_string))
}

draw_terminal :: proc() {
    fmt.printfln("\e[1;1H")
    fmt.print("\r")
    for yi in 0..<20 {
        for xi in 0..<20 {
            if math.floor(px) == f64(xi) && math.floor(py) == f64(yi) {
                fmt.print("X")
            } else {
                fmt.print(".")
            }
        }
        fmt.print('\n')
    }
}

vao, vbo, program: u32

init_draw_triangle :: proc() {
    program_result, program_ok := shader_program_from_file("bluevertex.glsl", "bluefrag.glsl")
    if !program_ok {
        fmt.eprintln("Failed to compile glsl")
        return
    }
    program = program_result

    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao)

    gl.GenBuffers(1, &vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    vertices := SHAPE_VERTICES[.Triangle2D]
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(glm.vec3), 0)
    gl.EnableVertexAttribArray(0)
}

draw_triangle :: proc(time: f64) {
    uniforms := gl.get_uniforms_from_program(program)
    gl.Uniform1f(uniforms["offset"].location, f32(time))

    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 3)
}
