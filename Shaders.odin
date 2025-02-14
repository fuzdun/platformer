package main
import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

ProgramName :: enum{
    Pattern,
    Outline,
    RedOutline,
    BlueOutline,
    New,
    Reactive,
    Player,
    Trail
}

Program :: struct{
    vertex_filename: string,
    frag_filename: string,
    init_proc: proc()
}

ActiveProgram :: struct{
    id: u32,
    ebo_id: u32,
    init_proc: proc()
}


PROGRAM_CONFIGS :: #partial[ProgramName]Program{
    .Pattern = {
        vertex_filename = "patternvertex",
        frag_filename = "patternfrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
            //gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Outline = {
        vertex_filename = "outlinevertex",
        frag_filename = "outlinefrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(3)
        }
    },
    .RedOutline = {
        vertex_filename = "outlinevertex",
        frag_filename = "redoutlinefrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(4)
        }
    },
    .BlueOutline = {
        vertex_filename = "outlinevertex",
        frag_filename = "blueoutlinefrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(4)
        }
    },
    .New = {
        vertex_filename = "patternvertex",
        frag_filename = "newfrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Player = {
        vertex_filename = "patternvertex",
        frag_filename = "playerfrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Reactive = {
        vertex_filename = "reactivevertex",
        frag_filename = "reactivefrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Trail = {
        vertex_filename = "trailvertex",
        frag_filename = "trailfrag",
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    } 
}

ShaderState :: struct {
    active_programs: map[ProgramName]ActiveProgram,
    loaded_program: u32,
}

shader_state_init :: proc(shst: ^ShaderState) {
    shst.active_programs = make(map[ProgramName]ActiveProgram)
}

shader_state_free :: proc(shst: ^ShaderState) {
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
        sh.active_programs[program] = { program_id, buf_id, config.init_proc }
    }
    return true
}

use_shader :: proc(sh: ^ShaderState, name: ProgramName) {
    if name in sh.active_programs {
        sh.loaded_program = sh.active_programs[name].id
        gl.UseProgram(sh.loaded_program)
        sh.active_programs[name].init_proc()
    }
}

shader_draw_triangles :: proc(rs: ^RenderState, sh: ^ShaderState, name: ProgramName) {
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, sh.active_programs[name].ebo_id)
    gl.DrawElements(gl.TRIANGLES, i32(len(rs.i_queue[name])), gl.UNSIGNED_SHORT, nil)
}

shader_draw_lines :: proc(rs: ^RenderState, sh: ^ShaderState, name: ProgramName) {
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, sh.active_programs[name].ebo_id)
    gl.DrawElements(gl.LINES, i32(len(rs.i_queue[name])), gl.UNSIGNED_SHORT, nil)
}

set_matrix_uniform :: proc(sh: ^ShaderState, name: string, data: ^glm.mat4) {
    cstr_name := strings.clone_to_cstring(name); defer delete(cstr_name)
    location := gl.GetUniformLocation(sh.loaded_program, cstr_name)
    gl.UniformMatrix4fv(location, 1, gl.FALSE, &data[0, 0])
}

set_float_uniform :: proc(sh: ^ShaderState, name: string, data: f32) {
    cstr_name := strings.clone_to_cstring(name); defer delete(cstr_name)
    location := gl.GetUniformLocation(sh.loaded_program, cstr_name)
    gl.Uniform1f(location, data)
}

set_vec3_uniform :: proc(sh: ^ShaderState, name: string, count: i32, data: ^glm.vec3) {
    cstr_name := strings.clone_to_cstring(name); defer delete(cstr_name)
    location := gl.GetUniformLocation(sh.loaded_program, cstr_name)
    gl.Uniform3fv(location, count, &data[0])
}

