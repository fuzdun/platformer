package main
import "core:os"
import str "core:strings"
import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"

transformed_vertex :: proc(vertex: Vertex, trns: Transform) -> Vertex {
    pos := la.quaternion128_mul_vector3(trns.rotation, vertex.pos.xyz * trns.scale) + trns.position
    norm := la.quaternion128_mul_vector3(trns.rotation, vertex.normal)
    return {{pos[0], pos[1], pos[2]}, vertex.uv, vertex.b_uv, norm}
}

trans_to_mat4 :: proc(trns: Transform) -> glm.mat4 {
    off := glm.mat4Translate(trns.position)
    rot := glm.mat4FromQuat(trns.rotation)
    scale := glm.mat4Scale(trns.scale)
    return off * rot * scale
}

generate_index_range :: proc(count: int, out: ^[dynamic]u32) {
    for i in 0..<count {
        append(out, u32(i))
    }  
}

get_ssbo_idx :: proc(lg: Level_Geometry, shader: ProgramName, rs: Render_State) -> int {
    group_idx := int(shader) * len(SHAPE) + int(lg.shape)
    group_offset := rs.render_group_offsets[group_idx]
    return int(group_offset) + lg.ssbo_indexes[shader]
}

