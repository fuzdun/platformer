package main
import "core:fmt"
import glm "core:math/linalg/glsl"

//apply_velocities :: proc(ecs: ^ECSState, dt: f64) {
//    using ecs.comp_data
//    ents := entities_with(ecs, {.Position, .Velocity})
//    for e in ents {
//        pos_i, vel_i := e[.Position], e[.Velocity]
//        positions[pos_i] += velocities[vel_i] * dt
//    }
//}

trans_apply_velocities :: proc(ecs: ^ECSState, dt: f64) {
    using ecs.comp_data
    ents := make([dynamic]uint); defer delete(ents)
    entities_with(ecs, {.Velocity, .Transform}, &ents)
    for e in ents {
        trans_i, vel_i := get_component(ecs, e, .Transform), get_component(ecs, e, .Velocity)
        old_t := transforms[trans_i]
        old_vel := velocities[vel_i]
        old_t *= glm.mat4Translate(velocities[vel_i])
        transforms[trans_i] = old_t
    }
}

//get_shapes :: proc(ecs: ^ECSState, dt: f64) {
//    using ecs.comp_data
//    ents := make([dynamic]uint); defer delete(ents)
//    entities_with(ecs, {.Shape}, &ents)
//    for e in ents {
//        shape_i := get_component(ecs, e, .Shape)
//        fmt.println(shapes[shape_i])
//    }
//}

