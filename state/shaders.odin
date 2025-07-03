package state

import enm "../enums"
import typ "../datatypes"

Shader_State :: struct {
    active_programs: map[enm.ProgramName]typ.Active_Program,
    loaded_program: u32,
    loaded_program_name: enm.ProgramName
}

free_shader_state :: proc(shst: ^Shader_State) {
    for _, ap in shst.active_programs {
        delete(ap.locations)
    }
    delete(shst.active_programs)
}

