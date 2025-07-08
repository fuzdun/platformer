package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"


Shader_State :: struct {
    active_programs: map[ProgramName]Active_Program,
    loaded_program: u32,
    loaded_program_name: ProgramName
}

free_shader_state :: proc(shst: ^Shader_State) {
    for _, ap in shst.active_programs {
        delete(ap.locations)
    }
    delete(shst.active_programs)
}

Program :: struct{
    pipeline: []string,
    uniforms: []string,
    shader_types: []gl.Shader_Type,
    init_proc: proc(),
}

Active_Program :: struct{
    id: u32,
    init_proc: proc(),
    locations: map[string]i32
}

ProgramName :: enum{
    Player,
    Trail,
    Simple,
    Background,
    Player_Particle,
    Outline,
    Text,
    Line
}

PROGRAM_CONFIGS :: #partial[ProgramName]Program{
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

use_shader :: proc(sh: ^Shader_State, rs: ^Render_State, name: ProgramName) {
    if name in sh.active_programs {
        gl.UseProgram(sh.active_programs[name].id)
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
        sh.active_programs[name].init_proc()
    }
}

set_matrix_uniform :: proc(sh: ^Shader_State, name: string, data: ^glm.mat4) {
    gl.UniformMatrix4fv(sh.active_programs[sh.loaded_program_name].locations[name], 1, gl.FALSE, &data[0, 0])
}

set_float_uniform :: proc(sh: ^Shader_State, name: string, data: f32) {
    gl.Uniform1f(sh.active_programs[sh.loaded_program_name].locations[name], data)
}

set_vec3_uniform :: proc(sh: ^Shader_State, name: string, count: i32, data: ^glm.vec3) {
    gl.Uniform3fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

