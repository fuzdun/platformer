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

Program :: struct {
    pipeline: []string,
    uniforms: []string,
    shader_types: []gl.Shader_Type,
}

Active_Program :: struct {
    id: u32,
    locations: map[string]i32
}

ProgramName :: enum {
    Player,
    Level_Geometry_Outline,
    Level_Geometry_Fill,
    Editor_Geometry,
    Background,
    Player_Particle,
    Connection_Line,
    Text,
    Dash_Line,
}

PROGRAM_CONFIGS :: #partial[ProgramName]Program {
    .Level_Geometry_Outline = {
        pipeline = {"lg_outline_vertex", "lg_outline_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {}
    },
    .Level_Geometry_Fill = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "lg_fill_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"player_trail", "player_pos", "crunch_time", "crunch_pt", "time", "projection"},
    },
    .Player = {
        pipeline = {"player_vertex", "player_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "i_time", "dash_time", "dash_end_time", "projection", "p_color", "constrain_dir"},
    },
    .Player_Particle = {
        pipeline = {"player_particle_vertex", "player_particle_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "player_pos", "i_time", "radius", "constrain_dir", "dash_time", "dash_end_time"},
    },
    .Editor_Geometry = {
        pipeline = {"editor_vertex", "editor_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection"},
    },
    .Background = {
        pipeline = {"background_vertex", "background_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"i_time"},
    },
    .Connection_Line = {
        pipeline = {"connection_line_vertex", "connection_line_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color"},
    },
    .Dash_Line = {
        pipeline = {"dash_line_vertex", "dash_line_geometry", "dash_line_frag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color", "line_dir", "dash_time", "i_time", "dash_dir", "resolution"},
    },
    .Text = {
        pipeline = {"text_vertex", "text_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "transform"},
    },
}

use_shader :: proc(sh: ^Shader_State, rs: ^Render_State, name: ProgramName) {
    if name in sh.active_programs {
        gl.UseProgram(sh.active_programs[name].id)
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
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

