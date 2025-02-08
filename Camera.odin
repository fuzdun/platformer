package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

Camera_State :: struct {
    position: [3]f32
}

move_camera :: proc(ps: Player_State, cs: ^Camera_State, elapsed_time: f64, delta_time: f32) {
    tgt_y := ps.position.y + 6 
    tgt_z := ps.position.z + 12
    tgt : [3]f32 = {ps.position.x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(0.05))
}
