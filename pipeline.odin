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

Ssbo_Info :: struct {
    id: u32,
    type: typeid
}

Ssbo_Infos := #partial[Ssbo]Ssbo_Info {
    .Z_Width = {
        type = glm.vec4
    },
    .Shatter = {
        type = Shatter_Ubo
    },
    .Transform = {
        type = glm.vec4
    },
    .Transparency = {
        type = Transparency_Ubo
    }
}

ssbo_mapper :: proc(rd: #soa[]Level_Geometry_Render_Data, ssbo: Ssbo, $T: typeid, loc: u32) {

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
            // transparency_ubos[i] = { 1 }
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

    gl.BindBuffer(gl.UNIFORM_BUFFER, loc)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(T) * len(rd), data)
    return
}

