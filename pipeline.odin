package main
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"


// #####################################################
// Render Pipeline Config 
// #####################################################
Ssbo :: enum {
    Transform,
    Transparency,
    Shatter,
    Z_Width
}

Ssbo_Info :: [Ssbo]struct{ type_sz: int, loc: u32 } {
    .Transform    = { size_of(glm.mat4),         4},
    .Z_Width      = { size_of(Z_Width_Ubo),      5},
    .Shatter      = { size_of(Shatter_Ubo),      6},
    .Transparency = { size_of(Transparency_Ubo), 7}
}

ssbo_mapper :: proc(rd: #soa[]Level_Geometry_Render_Data, bs: Buffer_State, ssbo: Ssbo) {

    data: rawptr
    switch ssbo {

    case .Transform:
        transform_mats := make([]glm.mat4, len(rd), context.temp_allocator)
        for i in 0..<len(rd) {
            transform_mats[i] = trans_to_mat4(rd.transform[i])
        }
        data = &transform_mats[0]

    case .Transparency:
        transparency_ubos := make([]Transparency_Ubo, len(rd), context.temp_allocator)
        for i in 0..<len(rd) {
            transparency_ubos[i] = { rd.transparency[i] }
        }
        data = &transparency_ubos[0]

    case .Shatter:
        data = rawptr(rd.shatter_data)

    case .Z_Width:
        z_widths := make([]Z_Width_Ubo, len(rd), context.temp_allocator)
        for i in 0..<len(rd) {
            z_widths[i] = { 20 }
        }
        data = &z_widths[0]
    }

    ssbo_info := Ssbo_Info
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, bs.ssbo_ids[ssbo])
    gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, ssbo_info[ssbo].type_sz * len(rd), data)
    return
}

