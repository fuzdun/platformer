package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import "core:os"

vao, vbo, ebo, program: u32
// sd := SHAPE_DATA[.InvertedPyramid]

world_vertices: [dynamic]Vertex
world_indices: [dynamic]u16

init_world :: proc(){
    world_vertices = make([dynamic]Vertex)
    world_indices = make([dynamic]u16)
}

add_to_world :: proc(shape: Shape) {
    append(&world_vertices, ..SHAPE_DATA[shape].vertices)
    append(&world_indices, ..SHAPE_DATA[shape].indices)
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
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(world_vertices[0]) * len(world_vertices), raw_data(world_vertices), gl.STATIC_DRAW)

    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(world_indices[0]) * len(world_indices), raw_data(world_indices), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
}

draw_triangles :: proc(time: f64) {

    scale := glm.mat4Scale({2.0, 2.0, 2.0})
    rot := glm.mat4Rotate({ 0, 1, 0}, f32(time))
    offset := glm.mat4Translate({f32(px), -.6, f32(py)})
    view := glm.mat4LookAt({0, 0, 1}, {0, 0, 0}, {0, 1, 0})
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)

    uniforms := gl.get_uniforms_from_program(program)
    gl.Uniform1f(uniforms["i_time"].location, f32(time))
    gl.UniformMatrix4fv(uniforms["scale"].location, 1, gl.FALSE, &scale[0, 0])
    gl.UniformMatrix4fv(uniforms["rotate"].location, 1, gl.FALSE, &rot[0, 0])
    gl.UniformMatrix4fv(uniforms["offset"].location, 1, gl.FALSE, &offset[0, 0])
    gl.UniformMatrix4fv(uniforms["view"].location, 1, gl.FALSE, &view[0, 0])
    gl.UniformMatrix4fv(uniforms["projection"].location, 1, gl.FALSE, &proj[0, 0])

    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.Enable(gl.DEPTH_TEST)
    gl.DrawElements(gl.TRIANGLES, i32(len(world_indices)), gl.UNSIGNED_SHORT, nil)
}
