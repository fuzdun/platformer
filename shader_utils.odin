package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import enm "enums"
import st "state"
import typ "datatypes"


use_shader :: proc(sh: ^st.Shader_State, rs: ^st.Render_State, name: enm.ProgramName) {
    if name in sh.active_programs {
        gl.UseProgram(sh.active_programs[name].id)
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
        sh.active_programs[name].init_proc()
    }
}

set_matrix_uniform :: proc(sh: ^st.Shader_State, name: string, data: ^glm.mat4) {
    gl.UniformMatrix4fv(sh.active_programs[sh.loaded_program_name].locations[name], 1, gl.FALSE, &data[0, 0])
}

set_float_uniform :: proc(sh: ^st.Shader_State, name: string, data: f32) {
    gl.Uniform1f(sh.active_programs[sh.loaded_program_name].locations[name], data)
}

set_vec3_uniform :: proc(sh: ^st.Shader_State, name: string, count: i32, data: ^glm.vec3) {
    gl.Uniform3fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

