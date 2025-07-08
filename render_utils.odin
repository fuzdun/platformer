package main

import glm "core:math/linalg/glsl"
import "core:math"

import typ "datatypes"


trans_to_mat4 :: proc(trns: typ.Transform) -> glm.mat4 {
    off := glm.mat4Translate(trns.position)
    rot := glm.mat4FromQuat(trns.rotation)
    scale := glm.mat4Scale(trns.scale)
    return off * rot * scale
}

easeout :: proc(n: f32) -> f32 {
    return math.sin(n * math.PI / 2.0);
}

