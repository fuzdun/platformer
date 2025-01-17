package main
import "core:os"
import str "core:strings"
import "core:fmt"
import gl "vendor:OpenGL"

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
