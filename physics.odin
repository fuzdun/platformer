package main
import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import "core:fmt"
import "core:math"

Physics_State :: struct {
    collisions: [dynamic]Collision,
    debug_render_queue: struct {
        vertices: [dynamic]Vertex,
        indices: [ProgramName][dynamic]u16
    }
}

Collision :: struct {
    id: int,
    pos: [3]f32,
    normal: [3]f32,
    plane_dist: f32,
    closest_pt: [3]f32,
    t: f32
}

AABB_INDICES :: []u16 {0, 1, 0, 3, 1, 2, 2, 3, 3, 7, 2, 6, 4, 5, 4, 7, 6, 7, 6, 5, 4, 0, 5, 1}

aabb_vertices :: proc(aabbx0: f32, aabby0: f32, aabbz0: f32, aabbx1: f32, aabby1: f32, aabbz1: f32,) -> [8]Vertex {
    return {
        {{aabbx0, aabby1, aabbz0, 1}, {0, 0}, {0, 0}},
        {{aabbx0, aabby0, aabbz0, 1}, {0, 1}, {0, 0}},
        {{aabbx1, aabby0, aabbz0, 1}, {1, 1}, {0, 0}},
        {{aabbx1, aabby1, aabbz0, 1}, {1, 0}, {0, 0}},

        {{aabbx0, aabby1, aabbz1, 1}, {1, 0}, {0, 0}},
        {{aabbx0, aabby0, aabbz1, 1}, {0, 0}, {0, 0}},
        {{aabbx1, aabby0, aabbz1, 1}, {0, 1}, {0, 0}},
        {{aabbx1, aabby1, aabbz1, 1}, {1, 1}, {0, 0}},
    }
}

init_physics_state :: proc(ps: ^Physics_State) {
    ps.collisions = make([dynamic]Collision)
    ps.debug_render_queue.vertices = make([dynamic]Vertex)
    for pn in ProgramName {
        ps.debug_render_queue.indices[pn] = make([dynamic]u16)
    }
}

clear_physics_state :: proc(ps: ^Physics_State) {
    clear(&ps.collisions)
    clear(&ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        clear(&iq)
    }
}

free_physics_state :: proc(ps: ^Physics_State) {
    delete(ps.collisions)
    delete(ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        delete(iq)
    }
}

get_collisions :: proc(gs: ^Game_State, ps: ^Physics_State, delta_time: f32, elapsed_time: f32) {
    clear_physics_state(ps)

    filter: bit_set[Level_Geometry_Component_Name; u64] = { .Collider, .Transform, .Shape }
    ppos := gs.player_state.position
    ppos32: [3]f32 = {f32(ppos[0]), f32(ppos[1]), f32(ppos[2])}
    px, py, pz := f32(ppos[0]), f32(ppos[1]), f32(ppos[2])
    player_sq_radius := f32(SPHERE_RADIUS * SPHERE_RADIUS)

    got_ground_ray_col := false
    for lg, id in gs.level_geometry {
        if filter <= lg.attributes {
            off := u16(len(ps.debug_render_queue.vertices))

            aabbx0, aabby0, aabbz0 := max(f32), max(f32), max(f32)
            aabbx1, aabby1, aabbz1 := min(f32), min(f32), min(f32)

            coll : Shape_Data
            coll = gs.level_colliders[lg.collider] 
            vertices := make([dynamic][3]f32); defer delete(vertices)
            trns := lg.transform
            for v, idx in coll.vertices {
                new_pos := la.quaternion128_mul_vector3(trns.rotation, trns.scale * v.pos.xyz) + trns.position
                append(&vertices, new_pos)
                aabbx0 = min(new_pos.x - 1, aabbx0)
                aabby0 = min(new_pos.y - 1, aabby0)
                aabbz0 = min(new_pos.z - 1, aabbz0)
                aabbx1 = max(new_pos.x + 1, aabbx1)
                aabby1 = max(new_pos.y + 1, aabby1)
                aabbz1 = max(new_pos.z + 1, aabbz1)
            }
            total : f32 = 0
            if px < aabbx0 do total += (px - aabbx0) * (px - aabbx0)
            if px > aabbx1 do total += (px - aabbx1) * (px - aabbx1)
            if py < aabby0 do total += (py - aabby0) * (py - aabby0)
            if py > aabby1 do total += (py - aabby1) * (py - aabby1)
            if pz < aabbz0 do total += (pz - aabbz0) * (pz - aabbz0)
            if pz > aabbz1 do total += (pz - aabbz1) * (pz - aabbz1)

            if gs.input_state.c_pressed {
                // debug wireframe rendering
                debug_vertices := aabb_vertices(aabbx0, aabby0, aabbz0, aabbx1, aabby1, aabbz1)
                append(&ps.debug_render_queue.vertices, ..debug_vertices[:])
            }
            if gs.input_state.c_pressed {
                // debug wireframe rendering
                shader: ProgramName = total < player_sq_radius ? .RedOutline : .Outline
                offset_indices(AABB_INDICES, off, &ps.debug_render_queue.indices[shader])
            }
            
            if total < player_sq_radius {
                // got player within bounding box
                coll_indices := make([dynamic]u16); defer delete(coll_indices)
                append(&coll_indices, ..coll.indices)
                l := len(coll_indices)
                for i := 0; i <= l - 3; i += 3 {
                    off := u16(len(ps.debug_render_queue.vertices))
                    tri_indices := coll_indices[i:i+3]
                    tri_vertex0 := vertices[tri_indices[0]]
                    tri_vertex1 := vertices[tri_indices[1]]
                    tri_vertex2 := vertices[tri_indices[2]]
                    velocity_normal := la.normalize(gs.player_state.velocity)
                    velocity_len := la.length(gs.player_state.velocity * delta_time)
                    closest_pt, normal, plane_dist := closest_triangle_pt(tri_vertex0, tri_vertex1, tri_vertex2, ppos32)
                    if la.dot(normal, velocity_normal) < 0 {
                        if sphere_t, sphere_q, sphere_ok := ray_sphere_intersect(closest_pt, -velocity_normal, ppos32); sphere_ok {
                            if sphere_t = sphere_t / velocity_len; sphere_t <= 1 {
                                // got collision with triangle
                                coll : Collision
                                coll.id = id
                                coll.pos = sphere_q
                                coll.normal = normal
                                coll.closest_pt = closest_pt
                                coll.plane_dist = plane_dist
                                coll.t = sphere_t
                                append(&ps.collisions, coll)
                            }
                        }
                    }
                    if gs.player_state.on_ground {
                        plane_t, plane_q, plane_ok := ray_plane_intersection(ppos32, gs.player_state.ground_ray, normal, plane_dist);
                        if plane_ok && la.length2(closest_pt - plane_q) < GROUNDED_RADIUS2 {
                            got_ground_ray_col = true
                            gs.player_state.position = plane_q + normal * GROUND_OFFSET 
                        }
                    }
                }
            }
        }         
    }
    if gs.player_state.on_ground {
        gs.player_state.on_ground = got_ground_ray_col
    }

    best_plane_normal: [3]f32 = {100, 100, 100}
    most_horizontal_coll: Collision = {} 
    best_plane_intersection: [3]f32 = {0, 0, 0}
    for coll in ps.collisions {
        ground_ray := -coll.normal * GROUND_RAY_LEN
        plane_t, plane_q, plane_ok := ray_plane_intersection(ppos32, ground_ray, coll.normal, coll.plane_dist);
        if plane_ok && la.length2(coll.closest_pt - plane_q) < GROUNDED_RADIUS2 {
            // ground_ray close enough to surface
            if abs(coll.normal.y) < best_plane_normal.y {
                best_plane_normal = coll.normal
                most_horizontal_coll = coll 
                best_plane_intersection = plane_q
            }
        }
    }
    if best_plane_normal.y < 100.0 {
        // the most horizontal surface
        if best_plane_normal.y >= 0.707 {
            if !gs.player_state.on_ground {
                gs.player_state.crunch_pt = gs.player_state.position - {0, 0, 0.5}
                gs.player_state.crunch_time = elapsed_time
            }
            gs.player_state.position = best_plane_intersection + best_plane_normal * GROUND_OFFSET 
            ground_x := [3]f32{1, 0, 0}
            ground_z := [3]f32{0, 0, -1}
            gs.player_state.ground_x = ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal
            gs.player_state.ground_z = ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal
            gs.player_state.ground_ray = -best_plane_normal * GROUND_RAY_LEN
            gs.player_state.on_ground = true
        } 
    }
}

ray_plane_intersection :: proc(start: [3]f32, offset: [3]f32, plane_n: [3]f32, plane_d: f32) -> (t: f32, q: [3]f32, ok: bool) {
    t = (plane_d - la.dot(plane_n, start)) / la.dot(plane_n, offset) 
    if t >= 0 && t <= 1 {
        q =  start + t * offset
        ok = true
        return
    }
    ok = false
    return
}

// returns closest pt, plane normal and plane distance from origin (scalar)
closest_triangle_pt :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32, p: [3]f32) -> ([3]f32, [3]f32, f32)  {
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
        return proj_pt, plane_n, plane_dist 
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
        return t01_pt, plane_n, plane_dist
    }
    if min == t12_len2 {
        return t12_pt, plane_n, plane_dist
    }
    if min == t20_len2 {
        return t20_pt, plane_n, plane_dist
    }
    return {0, 0, 0}, plane_n, plane_dist
}

closest_line_pt :: proc(l0: [3]f32, l1: [3]f32, p: [3]f32) -> [3]f32{
    line := l1 - l0
    t := la.dot(p - l0, line) / la.dot(line, line)
    t = clamp(t, 0, 1)
    return l0 + t * line
}

ray_sphere_intersect :: proc(origin: [3]f32, dir: [3]f32, ppos: [3]f32) -> (t: f32, q: [3]f32, ok: bool) {
    m := origin - ppos 
    b := la.dot(m, dir)
    c := la.dot(m, m) - SPHERE_SQ_RADIUS
    if c > 0 && b > 0 {
        ok = false
        return
    }
    discr := b * b - c
    if discr < 0 {
        ok = false
        return
    }
    t = max(-b - math.sqrt(discr), 0)
    q = origin + t * dir
    ok = true
    return
}

