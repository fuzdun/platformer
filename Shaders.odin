package main
import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

ProgramName :: enum {
    Pattern,
    Outline
}

Program :: struct{
    vertex_filename: string,
    frag_filename: string
}

ActiveProgram :: struct{
    id: u32
}

program_configs := [ProgramName]Program{
    .Pattern = {
        vertex_filename = "patternvertex",
        frag_filename = "patternfrag"
    },
    .Outline = {
        vertex_filename = "outlinevertex",
        frag_filename = "outlinefrag"
    }

}

active_programs : map[ProgramName]ActiveProgram
loaded_program : u32


init_shaders :: proc() -> bool {
    for config, program in program_configs {
        program_id, program_ok := shader_program_from_file(config.vertex_filename, config.frag_filename)
        if !program_ok {
            fmt.eprintln("Failed to compile glsl")
            return false
        }
        as: ActiveProgram = { program_id }
        active_programs[program] = as
    }
    return true
}

use_shader :: proc(name: ProgramName) {
    if name in active_programs {
        loaded_program = active_programs[name].id
        gl.UseProgram(loaded_program)
    }
}

set_matrix_uniform :: proc(name: string, data: ^glm.mat4) {
    location := gl.GetUniformLocation(loaded_program, strings.clone_to_cstring(name))
    gl.UniformMatrix4fv(location, 1, gl.FALSE, &data[0, 0])
}

set_float_uniform :: proc(name: string, data: f32) {
    location := gl.GetUniformLocation(loaded_program, strings.clone_to_cstring(name))
    gl.Uniform1f(location, data)
}