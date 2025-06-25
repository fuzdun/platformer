package main
import "core:fmt"
import str "core:strings"
import "core:os"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

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

Program :: struct{
    pipeline: []string,
    uniforms: []string,
    shader_types: []gl.Shader_Type,
    init_proc: proc(),
}

ActiveProgram :: struct{
    id: u32,
    init_proc: proc(),
    locations: map[string]i32
}

PROGRAM_CONFIGS := [ProgramName]Program{
    .Trail = {
        pipeline = EDIT ? {"simplevertex", "simplefrag"} : {"thumpervertex", "tessellationctrl", "tessellationeval", "thumpergeometry", "trailfrag"},
        shader_types = EDIT ? {.VERTEX_SHADER, .FRAGMENT_SHADER} : {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = EDIT ? {"projection"} : {"player_trail", "player_pos", "crunch_time", "crunch_pt", "time", "projection", "sonar_time"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
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

ShaderState :: struct {
    active_programs: map[ProgramName]ActiveProgram,
    loaded_program: u32,
    loaded_program_name: ProgramName
}

shader_state_init :: proc(shst: ^ShaderState) {
    shst.active_programs = make(map[ProgramName]ActiveProgram)
}

shader_state_free :: proc(shst: ^ShaderState) {
    for _, ap in shst.active_programs {
        delete(ap.locations)
    }
    delete(shst.active_programs)
}

init_shaders :: proc(sh: ^ShaderState) -> bool {
    for config, program in PROGRAM_CONFIGS {
        shaders := make([]u32, len(config.pipeline))
        defer delete(shaders)
        for filename, shader_i in config.pipeline {
            id, ok := shader_program_from_file(filename, config.shader_types[shader_i])
            if !ok {
                return false
            }
            shaders[shader_i] = id
        }

        program_id, program_ok := gl.create_and_link_program(shaders)
        if !program_ok {
            fmt.eprintln("program link failed:", program)
            return false
        }
        sh.active_programs[program] = {program_id, config.init_proc, make(map[string]i32)}
        prog := sh.active_programs[program]
        for uniform in config.uniforms {
            cstr_name := str.clone_to_cstring(uniform); defer delete(cstr_name)
            prog.locations[uniform] = gl.GetUniformLocation(program_id, cstr_name)
            sh.active_programs[program] = prog
        }
    }
    return true
}

shader_program_from_file :: proc(filename: string, type: gl.Shader_Type) -> (u32, bool) {
    dir := "shaders/"
    ext := ".glsl"
    filename := str.concatenate({dir, filename, ext})
    defer delete(filename)
    shader_string, shader_ok := os.read_entire_file(filename)
    defer delete(shader_string)
    if !shader_ok {
        fmt.eprintln("failed to read vertex shader file:", shader_string)
        return 0, false
    }
    shader_id, ok := gl.compile_shader_from_source(string(shader_string), type)
    if !ok {
        fmt.eprintln("failed to compile shader:", filename)
        return 0, false
    }
    return shader_id, true
}

use_shader :: proc(sh: ^ShaderState, rs: ^Render_State, name: ProgramName) {
    if name in sh.active_programs {
        gl.UseProgram(sh.active_programs[name].id)
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
        sh.active_programs[name].init_proc()
    }
}

set_matrix_uniform :: proc(sh: ^ShaderState, name: string, data: ^glm.mat4) {
    gl.UniformMatrix4fv(sh.active_programs[sh.loaded_program_name].locations[name], 1, gl.FALSE, &data[0, 0])
}

set_float_uniform :: proc(sh: ^ShaderState, name: string, data: f32) {
    gl.Uniform1f(sh.active_programs[sh.loaded_program_name].locations[name], data)
}

set_vec3_uniform :: proc(sh: ^ShaderState, name: string, count: i32, data: ^glm.vec3) {
    gl.Uniform3fv(sh.active_programs[sh.loaded_program_name].locations[name], count, &data[0])
}

