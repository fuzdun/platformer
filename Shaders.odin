package main
import "core:fmt"
import "core:strings"
import "core:os"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

ProgramName :: enum{
    Outline,
    RedOutline,
    Player,
    Trail
}

Program :: struct{
    vertex_filename: string,
    frag_filename: string,
    uniforms: []string,
    init_proc: proc()
}

ActiveProgram :: struct{
    id: u32,
    ebo_id: u32,
    init_proc: proc(),
    locations: map[string]i32
}

PROGRAM_CONFIGS := #partial[ProgramName]Program{
    .Outline = {
        vertex_filename = "outlinevertex",
        frag_filename = "outlinefrag",
        uniforms = {"projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(3)
        }
    },
    .RedOutline = {
        vertex_filename = EDIT ? "outlinevertex" : "outlinethumpervertex",
        frag_filename = "redoutlinefrag",
        uniforms = {"projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(4)
        }
    },
    .Trail = {
        vertex_filename = EDIT ? "trailvertex" : "thumpervertex",
        frag_filename = EDIT ? "reactivefrag" : "trailfrag",
        uniforms = {"player_trail_in", "player_pos_in", "crunch_time", "crunch_pt", "i_time", "projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Player = {
        vertex_filename = "playervertex",
        frag_filename = "playerfrag",
        uniforms = {"transform", "i_time", "projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
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
        program_id, program_ok := shader_program_from_file(config.vertex_filename, config.frag_filename)
        if !program_ok {
            fmt.eprintln("Failed to compile glsl")
            return false
        }
        buf_id: u32
        gl.GenBuffers(1, &buf_id)
        sh.active_programs[program] = {program_id, buf_id, config.init_proc, make(map[string]i32)}
        prog := sh.active_programs[program]
        for uniform in config.uniforms {
            cstr_name := strings.clone_to_cstring(uniform); defer delete(cstr_name)
            prog.locations[uniform] = gl.GetUniformLocation(program_id, cstr_name)
            sh.active_programs[program] = prog
        }
    }
    return true
}

use_shader :: proc(sh: ^ShaderState, rs: ^Render_State, name: ProgramName) {
    if name in sh.active_programs {
        sh.loaded_program = sh.active_programs[name].id
        sh.loaded_program_name = name
        gl.UseProgram(sh.loaded_program)
        sh.active_programs[name].init_proc()
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, sh.active_programs[name].ebo_id)
    }
}

shader_draw_triangles :: proc(rs: ^Render_State, sh: ^ShaderState, name: ProgramName) {
    gl.DrawElements(gl.TRIANGLES, i32(len(rs.static_indices_queue[name])), gl.UNSIGNED_SHORT, nil)
}

shader_draw_lines :: proc(rs: ^Render_State, sh: ^ShaderState, name: ProgramName) {
    gl.DrawElements(gl.LINES, i32(len(rs.static_indices_queue[name])), gl.UNSIGNED_SHORT, nil)
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

