package main

import "base:runtime"
import "core:fmt"
import "core:os"
import str "core:strings"

import gl "vendor:OpenGL"

init_shaders :: proc(shs: ^Shader_State, perm_alloc: runtime.Allocator) {
    shs.active_programs = make(map[ProgramName]Active_Program, perm_alloc)
    dir := "shaders/"
    ext := ".glsl"
    for config, program in PROGRAM_CONFIGS {
        shaders := make([]u32, len(config.pipeline), context.temp_allocator)
        for filename, shader_i in config.pipeline {
            type := config.shader_types[shader_i]
            filename := str.concatenate({dir, filename, ext}, context.temp_allocator)
            shader_string, shader_err := os.read_entire_file(filename, context.temp_allocator)
            if shader_err != os.ERROR_NONE {
                fmt.eprintln("failed to read shader file:", shader_string)
            }
            shader_id, ok := gl.compile_shader_from_source(string(shader_string), type)
            if !ok {
                fmt.eprintln("failed to compile shader:", filename)
            }
            shaders[shader_i] = shader_id
        }

        program_id, program_ok := gl.create_and_link_program(shaders)
        if !program_ok {
            fmt.eprintln("program link failed:", program)
        }
        shs.active_programs[program] = {program_id, make(map[string]i32)}
        prog := shs.active_programs[program]
        prog.locations = make(map[string]i32, perm_alloc)
        for uniform in config.uniforms {
            cstr_name := str.clone_to_cstring(uniform, context.temp_allocator)
            prog.locations[uniform] = gl.GetUniformLocation(program_id, cstr_name)
            shs.active_programs[program] = prog
        }
    }
}
