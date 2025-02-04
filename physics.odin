package main
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import "core:fmt"

Physics_State :: struct {
    vertices: [dynamic][3]f32,
    objects: [dynamic]Physics_Object,
    debug_render_queue: struct {
        vertices: [dynamic]Vertex,
        indices: [ProgramName][dynamic]u16
    }
}

Physics_Object :: struct {
    id: int,
    indices: [dynamic]u16,
}

AABB_INDICES :: []u16 {0, 1, 0, 3, 1, 2, 2, 3, 3, 7, 2, 6, 4, 5, 4, 7, 6, 7, 6, 5, 4, 0, 5, 1}

aabb_vertices :: proc(aabbx0: f32, aabby0: f32, aabbz0: f32, aabbx1: f32, aabby1: f32, aabbz1: f32,) -> [8]Vertex {
    return {
        {{aabbx0, aabby1, aabbz0, 1}, {0, 0}},
        {{aabbx0, aabby0, aabbz0, 1}, {0, 1}},
        {{aabbx1, aabby0, aabbz0, 1}, {1, 1}},
        {{aabbx1, aabby1, aabbz0, 1}, {1, 0}},

        {{aabbx0, aabby1, aabbz1, 1}, {1, 0}},
        {{aabbx0, aabby0, aabbz1, 1}, {0, 0}},
        {{aabbx1, aabby0, aabbz1, 1}, {0, 1}},
        {{aabbx1, aabby1, aabbz1, 1}, {1, 1}},
    }
}

init_physics_state :: proc(ps: ^Physics_State) {
    ps.vertices = make([dynamic][3]f32)
    ps.objects = make([dynamic]Physics_Object)
    ps.debug_render_queue.vertices = make([dynamic]Vertex)
    for pn in ProgramName {
        ps.debug_render_queue.indices[pn] = make([dynamic]u16)
    }
}

clear_physics_state :: proc(ps: ^Physics_State) {
    for &obj in ps.objects {
        delete(obj.indices)
    }
    clear(&ps.objects)
    clear(&ps.vertices)
    clear(&ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        clear(&iq)
    }
}

free_physics_state :: proc(ps: ^Physics_State) {
    for obj in ps.objects {
        delete(obj.indices)
    }
    delete(ps.vertices)
    delete(ps.objects)
    delete(ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        delete(iq)
    }
}

broad_phase_collisions :: proc(gs: ^Game_State, phys_s: ^Physics_State) {
    clear_physics_state(phys_s)

    filter : bit_set[Level_Geometry_Component_Name] = { .Colliding, .Position, .Shape }
    ppos := gs.player_state.position
    px, py, pz := f32(ppos[0]), f32(ppos[1]), f32(ppos[2])
    player_sq_radius := f32(SPHERE_RADIUS * SPHERE_RADIUS)

    for lg, id in gs.level_geometry {
        if filter <= lg.attributes {
            indices_offset := u16(len(phys_s.vertices))
            debug_indices_offset := u16(len(phys_s.debug_render_queue.vertices))

            aabbx0, aabby0, aabbz0 := max(f32), max(f32), max(f32)
            aabbx1, aabby1, aabbz1 := min(f32), min(f32), min(f32)

            sd := SHAPE_DATA[lg.shape]
            for v, idx in sd.vertices {
                new_pos := la.quaternion128_mul_vector3(lg.rotation, v.pos.xyz * lg.scale) + lg.position
                append(&phys_s.vertices, new_pos)
                aabbx0 = min(new_pos.x, aabbx0)
                aabby0 = min(new_pos.y, aabby0)
                aabbz0 = min(new_pos.z, aabbz0)
                aabbx1 = max(new_pos.x, aabbx1)
                aabby1 = max(new_pos.y, aabby1)
                aabbz1 = max(new_pos.z, aabbz1)
            }
            total : f32 = 0
            if px < aabbx0 do total += (px - aabbx0) * (px - aabbx0)
            if px > aabbx1 do total += (px - aabbx1) * (px - aabbx1)
            if py < aabby0 do total += (py - aabby0) * (py - aabby0)
            if py > aabby1 do total += (py - aabby1) * (py - aabby1)
            if pz < aabbz0 do total += (pz - aabbz0) * (pz - aabbz0)
            if pz > aabbz1 do total += (pz - aabbz1) * (pz - aabbz1)
            if total < player_sq_radius {
                po : Physics_Object
                po.id = id
                po.indices = make([dynamic]u16)
                for il in sd.indices_lists {
                    if il.shader == .Outline {
                        offset_indices(il.indices, indices_offset, &po.indices)
                    }
                }
                append(&phys_s.objects, po)
            }
            if gs.input_state.c_pressed {
                // debug wireframe rendering
                debug_vertices := aabb_vertices(aabbx0, aabby0, aabbz0, aabbx1, aabby1, aabbz1)
                append(&phys_s.debug_render_queue.vertices, ..debug_vertices[:])
            }
            if gs.input_state.c_pressed {
                // debug wireframe rendering
                shader: ProgramName = total < player_sq_radius ? .RedOutline : .Outline
                offset_indices(AABB_INDICES, debug_indices_offset, &phys_s.debug_render_queue.indices[shader])
            }
        }
    }
}

narrow_phase_collisions :: proc(gs: ^Game_State, ps: ^Physics_State) {
    player_sq_radius := f32(SPHERE_RADIUS * SPHERE_RADIUS)
    ppos := gs.player_state.position
    ppos32: [3]f32 = {f32(ppos[0]), f32(ppos[1]), f32(ppos[2])}
    for po in ps.objects {
        l := len(po.indices)
        for i := 0; i <= l - 3; i += 3 {
            off := u16(len(ps.debug_render_queue.vertices))
            tri_indices := po.indices[i:i+3] 
            tri_vertex0 := ps.vertices[tri_indices[0]]
            tri_vertex1 := ps.vertices[tri_indices[1]]
            tri_vertex2 := ps.vertices[tri_indices[2]]
            closest_pt, normal := closest_triangle_pt(tri_vertex0, tri_vertex1, tri_vertex2, ppos32)
            surface_penetration := SPHERE_RADIUS - la.length(closest_pt - ppos32)
            if surface_penetration >= 0 {
                if gs.input_state.c_pressed {
                    normal_offset := closest_pt + normal * surface_penetration * 5
                    v0: Vertex = {{tri_vertex0[0], tri_vertex0[1], tri_vertex0[2], 1}, {1, 1}}
                    v1: Vertex = {{tri_vertex1[0], tri_vertex1[1], tri_vertex1[2], 1}, {1, 1}}
                    v2: Vertex = {{tri_vertex2[0], tri_vertex2[1], tri_vertex2[2], 1}, {1, 1}}
                    v3: Vertex = {{closest_pt[0], closest_pt[1], closest_pt[2], 1}, {1, 1}}
                    v4: Vertex = {{normal_offset[0], normal_offset[1], normal_offset[2], 1}, {1, 1}}
                    append(&ps.debug_render_queue.indices[.BlueOutline], off, off + 1, off + 1, off + 2, off + 2, off, off + 3, off + 4)
                    append(&ps.debug_render_queue.vertices, v0, v1, v2, v3, v4)
                }
            }
        }         
    }
}

closest_triangle_pt :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32, p: [3]f32) -> ([3]f32,[3]f32)  {
    // get plane
    plane_n := la.normalize(la.cross(t1 - t0, t2 - t0)) // normal
    plane_dist := la.dot(plane_n, t0)
    // closest point on plane
    dist := la.dot(plane_n, p) - plane_dist
    proj_pt := p - dist * plane_n
    // check if projected point is in triangle
    a, b, c := t0, t1, t2
    a -= proj_pt 
    b -= proj_pt
    c -= proj_pt
    u, v, w := la.cross(b, c), la.cross(c, a), la.cross(a, b)
    if la.dot(u, v) >= 0 && la.dot(u, w) >= 0 {
        return proj_pt, plane_n 
    }
    // otherwise, get closest point in triangle edge line segments
    t01_pt := closest_line_pt(t0, t1, proj_pt)
    t12_pt := closest_line_pt(t1, t2, proj_pt)
    t20_pt := closest_line_pt(t2, t0, proj_pt)
    t01_len2 := la.length2(t01_pt - proj_pt)
    t12_len2 := la.length2(t12_pt - proj_pt)
    t20_len2 := la.length2(t20_pt - proj_pt)
    min := min(t01_len2, t12_len2, t20_len2)
    if min == t01_len2 {
        return t01_pt, plane_n
    }
    if min == t12_len2 {
        return t12_pt, plane_n
    }
    if min == t20_len2 {
        return t20_pt, plane_n
    }
    return {0, 0, 0}, plane_n
}

closest_line_pt :: proc(l0: [3]f32, l1: [3]f32, p: [3]f32) -> [3]f32{
    line := l1 - l0
    t := la.dot(p - l0, line) / la.dot(line, line)
    t = clamp(t, 0, 1)
    return l0 + t * line
}

