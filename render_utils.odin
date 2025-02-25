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
    filename := str.concatenate({dir, vertex_filename, ext})
    defer delete(filename)
    vertex_string, vertex_ok := os.read_entire_file(filename)
    defer delete(vertex_string)
    if !vertex_ok {
        fmt.eprintln("failed to read vertex shader file:", vertex_string)
        return 0, false
    }
    filename2 := str.concatenate({dir, fragment_filename, ext})
    defer delete(filename2)
    fragment_string, fragment_ok := os.read_entire_file(filename2)
    defer delete(fragment_string)
    if !fragment_ok {
        fmt.eprintln("failed to read fragment shader file:", fragment_string)
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

transform_vertices_arr :: proc(vertices: []Vertex, transforms: []glm.mat4, transform_counts: []int) -> []Vertex {
    out := make([dynamic]Vertex)
    idx := 0
    for count, i in transform_counts {
        for _ in 0..<count {
            v := vertices[idx]
            vertex: Vertex = { transforms[i] * v.pos, v.uv, v.b_uv, v.normal}
            append(&out, vertex)
            idx += 1
        }
    }
    return out[:]
}

transformed_vertex_pos :: proc(vertex: Vertex, trns: Transform) -> [3]f32 {
    return la.quaternion128_mul_vector3(trns.rotation, vertex.pos.xyz * trns.scale) + trns.position
}

transformed_vertex_normal :: proc(vertex: Vertex, trns: Transform) -> [3]f32 {
    return la.quaternion128_mul_vector3(trns.rotation, vertex.normal)
}

//transform_vertices :: proc(vertices: []Vertex, position: Position, scale: Scale, rotation: Rotation, out: ^[dynamic]Vertex) {
//    for v, idx in vertices {
//        new_pos := v.pos
//        new_pos.xyz = la.quaternion128_mul_vector3(rotation, new_pos.xyz * scale) + position
//        new_v : Vertex = {new_pos, v.uv, v.b_uv}
//        append(out, new_v)
//    }
//}

