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

Program_Init :: [ProgramName]proc(Buffer_State) {
    .Level_Geometry_Fill = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.BindTexture(gl.TEXTURE_2D, bs.dither_tex)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    },
    .Bouncy = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    },
    .Wireframe = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
    },
    .Barrier = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    },
    .Background = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.background_vao)
        gl.Disable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
    },
    .Level_Geometry_Outline = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    },
    .Player_Fill = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.player_vao)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.BLEND)
    },
    .Player_Outline = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.player_vao)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.LineWidth(1.5)
    },
    .Dash_Line = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.lines_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.editor_lines_vbo)
        gl.Enable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
        gl.LineWidth(2)
    },
    .Slide_Zone = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.standard_vao)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.BLEND)
    },
    .Trail_Particle = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.trail_particle_vao)
    },
    .Editor_Geometry = proc(bs: Buffer_State) {},
    .Player_Particle = proc(bs: Buffer_State) {},
    .Static_Line = proc(bs: Buffer_State) {},
    .Grid_Line = proc(bs: Buffer_State) {},
    .Text = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.text_vao)
    },
    .Postprocessing = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.background_vao)
        gl.BindTexture(gl.TEXTURE_2D, bs.postprocessing_tcb)
        gl.Enable(gl.CULL_FACE)
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.BLEND)
    },
    .Spin_Trails = proc(bs: Buffer_State) {
        gl.BindVertexArray(bs.spin_trails_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.spin_trails_vbo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.spin_trails_ebo)
        gl.Enable(gl.BLEND)
        gl.Enable(gl.CULL_FACE)
        gl.Enable(gl.DEPTH_TEST)
    },
    .Player = proc(bs: Buffer_State) {
    },
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
    Trail_Particle,
    Static_Line,
    Grid_Line,
    Text,
    Dash_Line,
    Player_Fill,
    Player_Outline,
    Postprocessing,
    Barrier,
    Wireframe,
    Slide_Zone,
    Bouncy,
    Spin_Trails 
}

PROGRAM_CONFIGS :: #partial[ProgramName]Program {
    .Barrier = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "barrier_fill_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {}
    },
    .Level_Geometry_Outline = {
        pipeline = {"lg_outline_vertex", "lg_outline_tessctrl", "lg_outline_tesseval", "lg_outline_geometry", "lg_outline_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"color"}
    },
    .Level_Geometry_Fill = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "lg_fill_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {},
    },
    .Bouncy = {
        pipeline = {"lg_fill_vertex", "lg_fill_tessctrl", "lg_fill_tesseval", "lg_fill_geometry", "bouncy_frag"},
        shader_types = {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {},
    },
    .Player = {
        pipeline = {"player_vertex", "player_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "p_color"},
    },
    .Player_Particle = {
        pipeline = {"player_particle_vertex", "player_particle_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"radius", "interp_t"},
    },
    .Trail_Particle = {
        pipeline = {"trail_particle_vertex", "trail_particle_geometry", "trail_particle_frag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"interp_t", "camera_dir", "delta_time"},
    },
    .Editor_Geometry = {
        pipeline = {"editor_vertex", "editor_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "selected_index"},
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
        uniforms = {"time", "ripple_pt", "crunch_time"}
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
    },
    .Spin_Trails = {
        pipeline = {"spin_trails_vertex", "spin_trails_frag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "camera_pos", "spin_amt"}
    },
}

use_shader :: proc(sh: ^Shader_State, rs: ^Render_State, bs: Buffer_State, name: ProgramName) {
    if name in sh.active_programs {
        gl.UseProgram(sh.active_programs[name].id)
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
    }
    program_inits := Program_Init
    program_inits[name](bs)
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

