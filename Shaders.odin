package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import enm "enums"
import st "state"
import typ "datatypes"


PROGRAM_CONFIGS := #partial[enm.ProgramName]typ.Program{
    .Trail = {
        pipeline = {"thumpervertex", "tessellationctrl", "tessellationeval", "thumpergeometry", "trailfrag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"player_trail", "player_pos", "crunch_time", "crunch_pt", "time", "projection", "sonar_time"},
        init_proc = proc() {
             //gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Player = {
        pipeline = {"playervertex", "playerfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "i_time", "dash_time", "dash_end_time", "projection", "p_color", "constrain_dir"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Player_Particle = {
        pipeline = {"particlevertex", "particlefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "player_pos", "i_time", "radius", "constrain_dir", "dash_time", "dash_end_time"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Simple = {
        pipeline = {"simplevertex", "simplefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Background = {
        pipeline = {"backgroundvertex", "backgroundfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"i_time"},
        init_proc = proc(){
            // gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }
    },
    .Outline = {
        pipeline = {"outlinevertex", "outlinefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINES)
        }
    },
    .Line = {
        pipeline = {"linevertex", "linegeometry", "linefrag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color", "line_dir", "dash_time", "i_time", "dash_dir", "resolution"},
        init_proc = proc() {

        }
    },
    .Text = {
        pipeline = {"textvertex", "textfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "transform"},
        init_proc = proc() {}
    },
}

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

