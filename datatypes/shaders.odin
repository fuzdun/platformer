package datatypes

import gl "vendor:OpenGL"

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

