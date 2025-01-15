package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

Shape :: enum{Triangle, InvertedPyramid}
Vertex :: struct {
    pos: glm.vec3,
    uv: glm.vec2
}
ShapeData :: struct {
    vertices: []Vertex,
    indices: []u16
}

SHAPE_DATA :: #partial [Shape]ShapeData{
    .Triangle = {
        {
            {{-0.5, -0.5, 0}, {0, 0}},
            {{0.5, -0.5, 0}, {1, 0}},
            {{0, 0.5, 0}, {0.5, 1}}
        },
        {
           0, 1, 2 
        }
    },
    .InvertedPyramid = {
        {
            {{-0.25, 0.25, -0.25}, {1, 1}},
            {{0, -0.25, 0}, {0, 0}},
            {{0.25, 0.25, -0.25}, {1, -1}},
            {{0.25, 0.25, 0.25}, {-1, -1}},
            {{-0.25, 0.25, 0.25}, {-1, 1}},
        },
        {
            0, 1, 2,
            2, 1, 3,
            3, 1, 4,
            4, 1, 0,
            0, 2, 4,
            2, 3, 4
        }
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

vao, vbo, ebo, program: u32
sd := SHAPE_DATA[.InvertedPyramid]

init_draw_triangle :: proc() {
    // sd := SHAPE_DATA[.InvertedPyramid]
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
    gl.BufferData(gl.ARRAY_BUFFER, size_of(sd.vertices[0]) * len(sd.vertices), raw_data(sd.vertices), gl.STATIC_DRAW)

    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(sd.indices[0]) * len(sd.indices), raw_data(sd.indices), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
}

draw_triangle :: proc(time: f64) {

    scale := glm.mat4Scale({2.0, 2.0, 2.0})
    rot := glm.mat4Rotate({ 0, 1, 0}, f32(time))
    offset := glm.mat4Translate({f32(px), -.6, f32(py)})
    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)

    uniforms := gl.get_uniforms_from_program(program)
    gl.UniformMatrix4fv(uniforms["scale"].location, 1, gl.FALSE, &scale[0, 0])
    gl.UniformMatrix4fv(uniforms["rotate"].location, 1, gl.FALSE, &rot[0, 0])
    gl.UniformMatrix4fv(uniforms["offset"].location, 1, gl.FALSE, &offset[0, 0])
    gl.UniformMatrix4fv(uniforms["view"].location, 1, gl.FALSE, &view[0, 0])
    gl.UniformMatrix4fv(uniforms["projection"].location, 1, gl.FALSE, &proj[0, 0])

    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.Enable(gl.DEPTH_TEST)
    gl.DrawElements(gl.TRIANGLES, i32(len(sd.indices)), gl.UNSIGNED_SHORT, nil)
}
