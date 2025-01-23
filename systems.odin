package main
import "core:fmt"
import glm "core:math/linalg/glsl"

trans_apply_velocities :: proc(ecs: ^ECS, dt: f64) {
    query := [?]Component { .Velocity, .Transform }
    entities_update(ecs, query, proc(ecs: ^ECS, e: map[Component]uint) {
        transform, velocity := get_transform(ecs, e), get_velocity(ecs, e)
        new_transform := transform^ 
        new_transform *= glm.mat4Translate(velocity^)
        transform^ = new_transform
    })
}

entities_update :: proc(ecs: ^ECS, cmps: [$N]Component, f: proc(^ECS, map[Component]uint)) {
    ents := make([dynamic][N]uint); defer delete(ents)
    entities_with(ecs, cmps, &ents)
    ents_map := make([]map[Component]uint, len(ents)); defer delete(ents_map)
    for e, e_idx in ents {
        for c, c_idx in cmps {
            ents_map[e_idx][c] = e[c_idx]
        }
    }
    for e in ents_map {
        f(ecs, e)
    }
}

entities_with :: proc(ecs: ^ECS, cmps: [$N]Component, out: ^[dynamic][N]uint) {
    e_loop: for e, i in ecs.entities.packed {
        set : [N]uint
        for cmp, j in cmps {
            c_idx := get_component_idx(ecs, e, cmp) or_continue e_loop
            set[j] = c_idx
        }
        append(out, set)
    }
}

