package state

import glm "core:math/linalg/glsl"

import enm "../enums"
import typ "../datatypes"

Physics_State :: struct{
    collisions: [dynamic]typ.Collision,
    debug_render_queue: struct {
        vertices: [dynamic]typ.Vertex,
        indices: [enm.ProgramName][dynamic]u16
    },
    level_colliders: [enm.SHAPE]typ.Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
}

free_physics_state :: proc(ps: ^Physics_State) {
    delete(ps.collisions)
    delete(ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        delete(iq)
    }
    for coll in ps.level_colliders {
        delete(coll.indices) 
        delete(coll.vertices)
    }
    //delete(ps.level_colliders)
    delete(ps.static_collider_vertices)
}

