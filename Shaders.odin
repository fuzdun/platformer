package main
import "core:fmt"
import str "core:strings"
import "core:os"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

ProgramName :: enum{
    Outline,
    RedOutline,
    Player,
    Trail,
    Simple
}

Program :: struct{
    vertex_filename: string,
    frag_filename: string,
    uniforms: []string,
    init_proc: proc(),
    use_geometry_shader: bool,
    geometry_filename: string
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
        },
        use_geometry_shader = false,
        geometry_filename = ""
    },
    .RedOutline = {
        vertex_filename = EDIT ? "outlinevertex" : "outlinethumpervertex",
        frag_filename = "redoutlinefrag",
        uniforms = {"projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.LINE)
            gl.LineWidth(4)
        },
        use_geometry_shader = false,
        geometry_filename = ""
    },
    .Trail = {
        vertex_filename = EDIT ? "trailvertex" : "thumpervertex",
        frag_filename = EDIT ? "reactivefrag" : "trailfrag",
        uniforms = {"player_trail_in", "player_pos_in", "crunch_time", "crunch_pt", "i_time", "projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        },
        use_geometry_shader = true,
        geometry_filename = "thumpergeometry"
    },
    .Player = {
        vertex_filename = "playervertex",
        frag_filename = "playerfrag",
        uniforms = {"transform", "i_time", "projection"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        },
        use_geometry_shader = false,
        geometry_filename = ""
    },
    .Simple = {
        vertex_filename = "simplevertex",
        frag_filename = "simplefrag",
        geometry_filename = "simplegeometry",
        use_geometry_shader = true,
        uniforms = {"projection", "transform"},
        init_proc = proc() {
            gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    }
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
        vertex_id, vertex_ok := shader_program_from_file(config.vertex_filename, .VERTEX_SHADER)
        if !vertex_ok {
            fmt.eprintln("Failed to compile glsl")
            return false
        }
        geometry_id: u32 = 0
        geometry_ok := false
        if config.use_geometry_shader {
            geometry_id, geometry_ok = shader_program_from_file(config.geometry_filename, .GEOMETRY_SHADER)
            if !geometry_ok {
                fmt.eprintln("Failed to compile glsl")
                return false
            }
            //gl.AttachShader(program_id, geometry_id)
        }
        frag_id, frag_ok := shader_program_from_file(config.frag_filename, .FRAGMENT_SHADER)
        if !frag_ok {
            fmt.eprintln("Failed to compile glsl")
            return false
        }
        program_id: u32 = 0
        program_ok := false
        if config.use_geometry_shader {
            program_id, program_ok = gl.create_and_link_program({vertex_id, geometry_id, frag_id}) 
            //program_id, program_ok = gl.create_and_link_program({vertex_id, frag_id})
        } else {
            program_id, program_ok = gl.create_and_link_program({vertex_id, frag_id})
        }
        //gl.LinkProgram(program_id)
        buf_id: u32
        gl.GenBuffers(1, &buf_id)
        sh.active_programs[program] = {program_id, buf_id, config.init_proc, make(map[string]i32)}
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
    //shader_cstr := cstring(raw_data(shader_string))
    //gl.ShaderSource(shader_id, 1, &shader_cstr, nil)
    //gl.CompileShader(shader_id)
    return shader_id, true
}

//shader_program_from_file :: proc(vertex_filename, fragment_filename: string) -> (u32, bool) {
//    dir := "shaders/"
//    ext := ".glsl"
//    filename := str.concatenate({dir, vertex_filename, ext})
//    defer delete(filename)
//    vertex_string, vertex_ok := os.read_entire_file(filename)
//    defer delete(vertex_string)
//    if !vertex_ok {
//        fmt.eprintln("failed to read vertex shader file:", vertex_string)
//        return 0, false
//    }
//    filename2 := str.concatenate({dir, fragment_filename, ext})
//    defer delete(filename2)
//    fragment_string, fragment_ok := os.read_entire_file(filename2)
//    defer delete(fragment_string)
//    if !fragment_ok {
//        fmt.eprintln("failed to read fragment shader file:", fragment_string)
//        return 0, false
//    }
//    program_id := gl.CreateProgram()
//    vertex_id := gl.CreateShader(gl.VERTEX_SHADER)
//    fragment_id := gl.CreateShader(gl.FRAGMENT_SHADER)
//
//    vertex_cstr := cstring(raw_data(vertex_string))
//    fragment_cstr := cstring(raw_data(fragment_string))
//
//    gl.ShaderSource(vertex_id, 1, &vertex_cstr, nil)
//    gl.ShaderSource(fragment_id, 1, &fragment_cstr, nil)
//    gl.CompileShader(vertex_id)
//    gl.CompileShader(fragment_id)
//    gl.AttachShader(program_id, vertex_id)
//    gl.AttachShader(program_id, fragment_id)
//    return program_id, true
//}
//

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
    gl.DrawElements(gl.TRIANGLES, i32(len(rs.static_indices_queue[name])), gl.UNSIGNED_INT, nil)
}

shader_draw_lines :: proc(rs: ^Render_State, sh: ^ShaderState, name: ProgramName) {
    gl.DrawElements(gl.LINES, i32(len(rs.static_indices_queue[name])), gl.UNSIGNED_INT, nil)
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

