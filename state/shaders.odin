package state

import gl "vendor:OpenGL"

import enm "enums"

Shader_State :: struct {
    active_programs: map[enm.ProgramName]ActiveProgram,
    loaded_program: u32,
    loaded_program_name: enm.ProgramName
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

ActiveProgram :: struct{
    id: u32,
    init_proc: proc(),
    locations: map[string]i32
}

