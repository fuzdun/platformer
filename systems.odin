package main
import "core:fmt"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import "core:slice"

trans_apply_velocities :: proc(ecs: ^ECS, dt: f64) {
    ents := entities_with(ecs, { .Velocity, .Transform }); defer delete(ents)
    for e in ents {
        transform := get_transform(ecs,e) or_else nil
        velocity := get_velocity(ecs, e) or_else nil
        new_transform := transform^ 
        new_transform *= glm.mat4Translate(velocity^ * f32(dt))
        transform^ = new_transform
    }
}

