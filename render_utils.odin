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

