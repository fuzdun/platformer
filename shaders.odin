package main

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"


Shader_State :: struct {
    active_programs: map[ProgramName]Active_Program,
    loaded_program: u32,
    loaded_program_name: ProgramName
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
    Static_Line,
    Grid_Line,
    Text,
    Dash_Line,
    Screen_Dither,
    Player_Fill,
    Player_Outline,
    Postprocessing,
    Barrier,
    Wireframe,
    Slide_Zone,
    Bouncy
}

PROGRAM_CONFIGS :: #partial[ProgramName]Program {
    .Barrier = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "barrier_fill_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"shatter_delay", "inverse_view", "inverse_projection", "camera_pos"}
    },
    .Level_Geometry_Outline = {
        pipeline = {"lg_outline_vertex", "lg_outline_tessctrl", "lg_outline_tesseval", "lg_outline_geometry", "lg_outline_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color"}
    },
    .Level_Geometry_Fill = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "lg_fill_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"player_trail", "crunch_time", "crunch_pt", "camera_pos", "inverse_projection", "inverse_view", "shatter_delay", "slide_t"},
    },
    .Bouncy = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "bouncy_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"player_trail", "crunch_time", "crunch_pt", "camera_pos", "inverse_projection", "inverse_view", "shatter_delay", "slide_t"},
    },
    .Player = {
        pipeline = {"player_vertex", "player_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "p_color"},
    },
    .Player_Particle = {
        pipeline = {"player_particle_vertex", "player_particle_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"radius"},
    },
    .Editor_Geometry = {
        pipeline = {"editor_vertex", "editor_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection"},
    },
    .Background = {
        pipeline = {"background_vertex", "background_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"crunch_pt_count", "crunch_pts"},
    },
    .Static_Line = {
        pipeline = {"static_line_vertex", "static_line_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color"},
    },
    .Grid_Line = {
        pipeline = {"grid_line_vertex", "grid_line_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color", "edit_pos"},
    },
    .Dash_Line = {
        pipeline = {"dash_line_vertex", "dash_line_geometry", "dash_line_frag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color", "resolution"},
    },
    .Text = {
        pipeline = {"text_vertex", "text_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "transform"},
    },
    .Screen_Dither = {
        pipeline = {"screen_dither_vertex", "screen_dither_geometry", "screen_dither_frag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"inverse_projection", "inverse_view", "projection", "camera_pos"}
    },
    .Player_Fill = {
        pipeline = {"player_fill_vertex", "player_fill_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"p_color", "transform"}
    },
    .Player_Outline = {
        pipeline = {"player_outline_vertex", "player_outline_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "p_outline_color"}
    },
    .Postprocessing = {
        pipeline = {"postprocessing_vertex", "postprocessing_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"time", "ppos", "crunch_time"}
    },
    .Wireframe = {
        pipeline = {"wireframe_vertex", "wireframe_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color", "camera_pos"}
    },
    .Slide_Zone = {
        pipeline = {"slide_zone_vertex", "slide_zone_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"shatter_delay"}
    }
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

set_int_uniform :: proc(sh: ^Shader_State, name: string, data: i32) {
    gl.Uniform1i(sh.active_programs[sh.loaded_program_name].locations[name], data)
}

set_vec2_uniform :: proc(sh: ^Shader_State, name: string, count: i32, data: ^glm.vec2) {
    gl.Uniform2fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

set_vec3_uniform :: proc(sh: ^Shader_State, name: string, count: i32, data: ^glm.vec3) {
    gl.Uniform3fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

set_vec4_uniform :: proc(sh: ^Shader_State, name: string, count: i32, data: ^glm.vec4) {
    gl.Uniform4fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

