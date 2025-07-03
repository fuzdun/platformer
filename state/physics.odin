package state

import glm "core:math/linalg/glsl"

import enm "enums"

Physics_State :: struct{
    collisions: [dynamic]Collision,
    debug_render_queue: struct {
        vertices: [dynamic]Vertex,
        indices: [enm.ProgramName][dynamic]u16
    },
    level_colliders: [enm.SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
}

Collision :: struct{
    id: int,
    normal: [3]f32,
    plane_dist: f32,
    contact_dist: f32,
    t: f32
}

Collider_Data :: struct{
    vertices: [][3]f32,
    indices: []u16
}

init_physics_state :: proc(ps: ^Physics_State) {
    ps.collisions = make([dynamic]Collision)
    ps.debug_render_queue.vertices = make([dynamic]Vertex)
    //ps.level_colliders = make(map[string]Collider_Data)
    ps.static_collider_vertices = make([dynamic][3]f32)
    for pn in enm.ProgramName {
        ps.debug_render_queue.indices[pn] = make([dynamic]u16)
    }
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

