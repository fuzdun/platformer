package main
import "core:os"
import str "core:strings"
import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"

shader_program_from_file :: proc(vertex_filename, fragment_filename: string) -> (u32, bool) {
    dir := "shaders/"
    ext := ".glsl"
    vertex_string, vertex_ok := os.read_entire_file(str.concatenate({dir, vertex_filename, ext}))
    if !vertex_ok {
        fmt.println("failed to read vertex shader file")
        return 0, false
    }
    fragment_string, fragment_ok := os.read_entire_file(str.concatenate({dir, fragment_filename, ext}))
    if !fragment_ok {
        fmt.println("failed to read fragment shader file")
        return 0, false
    }
    return gl.load_shaders_source(string(vertex_string), string(fragment_string))
}

offset_indices :: proc(indices: []u16, offset: u16, out: ^[dynamic]u16) {
    for ind, i in indices {
        append(out, ind + offset)
    }
}

rotate_transforms :: proc(time: f64, transforms: ^[dynamic]glm.mat4) {
    for &transform in transforms {
        transform = glm.mat4Rotate({ 0, 1, 0}, f32(time) / 1000 )
    }
}

transform_vertices :: proc(vertices: [dynamic]Vertex, transforms: [dynamic]glm.mat4, transform_counts: [dynamic]int, out: ^[dynamic]Vertex) {
    idx := 0
    for count, i in transform_counts {
        for _ in 0..<count {
            v := vertices[idx]
            vertex: Vertex = { transforms[i] * v.pos, v.uv }
            append(out, vertex)
            idx += 1
        }
    }
}
