package main
import "core:os"
import str "core:strings"
import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import "core:math"
import st "state"
import enm "state/enums"

transformed_vertex :: proc(vertex: st.Vertex, trns: st.Transform) -> st.Vertex {
    pos := la.quaternion128_mul_vector3(trns.rotation, vertex.pos.xyz * trns.scale) + trns.position
    norm := la.quaternion128_mul_vector3(trns.rotation, vertex.normal)
    return {{pos[0], pos[1], pos[2]}, vertex.uv, vertex.b_uv, norm}
}

trans_to_mat4 :: proc(trns: st.Transform) -> glm.mat4 {
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

get_ssbo_idx :: proc(lg: st.Level_Geometry, shader: enm.ProgramName, rs: st.Render_State) -> int {
    group_idx := int(shader) * len(enm.SHAPE) + int(lg.shape)
    group_offset := rs.render_group_offsets[group_idx]
    return int(group_offset) + lg.ssbo_indexes[shader]
}

easeout :: proc(n: f32) -> f32 {
    return math.sin(n * math.PI / 2.0);
}

