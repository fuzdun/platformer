package main

import glm "core:math/linalg/glsl"
import la "core:math/linalg"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:time"

import st "state"
import enm "enums"
import const "constants"
import typ "datatypes"

//get_collisions :: proc(gs: ^st.Game_State, pls: ^st.Player_State, ps: ^st.Physics_State, delta_time: f32, elapsed_time: f32) {
//    st.clear_physics_state(ps)
//
//    filter: bit_set[enm.Level_Geometry_Component_Name; u64] = { .Collider, .Transform }
//    ppos := pls.position
//    ppos32: [3]f32 = {f32(ppos[0]), f32(ppos[1]), f32(ppos[2])}
//    px, py, pz := f32(ppos[0]), f32(ppos[1]), f32(ppos[2])
//    player_sq_radius := f32(const.SPHERE_RADIUS * const.SPHERE_RADIUS)
//    player_velocity := pls.velocity * delta_time
//    player_velocity_len := la.length(player_velocity)
//
//    got_contact_ray_col := false
//
//    transformed_coll_vertices := ps.static_collider_vertices
//
//    tv_offset := 0
//
//    for lg, id in gs.level_geometry {
//        coll := ps.level_colliders[lg.collider] 
//        if filter <= lg.attributes {
//            vertices := transformed_coll_vertices[tv_offset:tv_offset + len(coll.vertices)] 
//            aabb := lg.aabb
//
//            total : f32 = 0
//            if px < lg.aabb.x0 do total += (px - lg.aabb.x0) * (px - lg.aabb.x0)
//            if px > lg.aabb.x1 do total += (px - lg.aabb.x1) * (px - lg.aabb.x1)
//            if py < lg.aabb.y0 do total += (py - lg.aabb.y0) * (py - lg.aabb.y0)
//            if py > lg.aabb.y1 do total += (py - lg.aabb.y1) * (py - lg.aabb.y1)
//            if pz < lg.aabb.z0 do total += (pz - lg.aabb.z0) * (pz - lg.aabb.z0)
//            if pz > lg.aabb.z1 do total += (pz - lg.aabb.z1) * (pz - lg.aabb.z1)
//
//            if total < player_sq_radius {
//                // got player within bounding box
//                l := len(coll.indices)
//                for i := 0; i <= l - 3; i += 3 {
//                    tri_indices := coll.indices[i:i+3]
//                    tri_vertex0 := vertices[tri_indices[0]]
//                    tri_vertex1 := vertices[tri_indices[1]]
//                    tri_vertex2 := vertices[tri_indices[2]]
//                    velocity_normal := la.normalize(pls.velocity)
//                    normal, plane_dist := triangle_normal_dist(tri_vertex0, tri_vertex1, tri_vertex2)
//                    if la.dot(normal, velocity_normal) <= 0 {
//                        intercept_t: f32
//                        intercept_pt: [3]f32
//                        did_intercept := false
//                        if intercept_pt, did_intercept = sphere_intersects_plane(ppos32, const.SPHERE_RADIUS, normal, plane_dist); did_intercept {
//                            intercept_t = 0
//                        } else {
//                            sphere_contact_pt := ppos32 - normal * const.SPHERE_RADIUS
//                            intercept_t, intercept_pt, did_intercept = ray_plane_intersection(sphere_contact_pt, player_velocity, normal, plane_dist);
//                        }
//                        if did_intercept {
//                            if pt_inside_triangle(tri_vertex0, tri_vertex1, tri_vertex2, intercept_pt) {
//                                pls.bunny_hop_y = max(f32)
//                                append(&ps.collisions, typ.Collision{
//                                    id = id,
//                                    normal = normal,
//                                    contact_dist = 0,
//                                    plane_dist = plane_dist,
//                                    t = intercept_t
//                                }) 
//                            } else {
//                                closest_pt := closest_triangle_edge_pt(tri_vertex0, tri_vertex1, tri_vertex2, intercept_pt)
//                                if sphere_t, sphere_q, sphere_hit := ray_sphere_intersect(closest_pt, -velocity_normal, ppos32); sphere_hit {
//                                    if sphere_t = sphere_t / player_velocity_len; sphere_t <= 1 {
//                                        pls.bunny_hop_y = max(f32)
//                                        append(&ps.collisions, typ.Collision{
//                                            id = id,
//                                            normal = normal,
//                                            contact_dist = la.length2(closest_pt - intercept_pt),
//                                            plane_dist = plane_dist,
//                                            t = sphere_t
//                                        })
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    if plane_t, plane_q, plane_hit := ray_plane_intersection(ppos32, pls.contact_ray, normal, plane_dist); plane_hit {
//                        closest_pt := closest_triangle_pt(tri_vertex0, tri_vertex1, tri_vertex2, plane_q)
//                        if la.length2(closest_pt - plane_q) < const.GROUNDED_RADIUS2 {
//                            got_contact_ray_col = true
//                            if pls.state == .ON_GROUND {
//                                //gs.player_state.position = plane_q + normal * GROUND_OFFSET 
//                            }
//                        }
//                    }
//                }
//            }
//        }         
//        tv_offset += len(coll.vertices)
//    }
//
//    p_state := pls.state
//    if (p_state == .ON_GROUND || p_state == .ON_WALL || p_state == .ON_SLOPE) && !got_contact_ray_col {
//        pls.state = .IN_AIR
//    }
//    if p_state == .ON_GROUND {
//        pls.left_ground = elapsed_time
//    }
//    if p_state == .ON_SLOPE {
//        pls.left_slope = elapsed_time
//    }
//    if p_state == .ON_WALL {
//        pls.left_wall = elapsed_time
//    }
//
//    best_plane_normal: [3]f32 = {100, 100, 100}
//    most_horizontal_coll: typ.Collision = {} 
//    best_plane_intersection: [3]f32 = {0, 0, 0}
//    for coll in ps.collisions {
//        contact_ray := -coll.normal * player_velocity_len
//        plane_t, plane_q, plane_ok := ray_plane_intersection(ppos32, contact_ray, coll.normal, coll.plane_dist);
//        //if plane_ok && la.length2(coll.closest_pt - plane_q) < GROUNDED_RADIUS2 {
//        if coll.contact_dist < const.GROUNDED_RADIUS2 {
//            // ground_ray close enough to surface
//            if abs(coll.normal.y) < best_plane_normal.y {
//                best_plane_normal = coll.normal
//                most_horizontal_coll = coll 
//                best_plane_intersection = plane_q
//            }
//        }
//    }
//    if best_plane_normal.y < 100.0 {
//        // the most horizontal surface
//        ground_x := [3]f32{1, 0, 0}
//        ground_z := [3]f32{0, 0, -1}
//        if best_plane_normal.y >= 0.85{
//            if pls.state != .ON_GROUND {
//                pls.touch_pt = pls.position - {0, 0, 0.5}
//                pls.touch_time = elapsed_time
//            }
//            //pls.position = best_plane_intersection + best_plane_normal * GROUND_OFFSET 
//            pls.ground_x = la.normalize(ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal)
//            pls.ground_z = la.normalize(ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal)
//            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
//            pls.state = .ON_GROUND
//        } else if .2 <= best_plane_normal.y && best_plane_normal.y < .85 {
//            if pls.state != .ON_SLOPE {
//                pls.touch_pt = pls.position - {0, 0, 0.5}
//                pls.touch_time = elapsed_time
//                pls.ground_x = ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal
//                pls.ground_z = ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal
//                pls.state = .ON_SLOPE
//            }
//            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
//        } else if best_plane_normal.y < .2 && pls.state != .ON_GROUND {
//            if pls.state != .ON_WALL {
//                pls.touch_pt = pls.position - {0, 0, 0.5}
//                pls.touch_time = elapsed_time
//            }
//            pls.state = .ON_WALL
//            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
//        }
//    }
//}

get_collisions :: proc(gs: ^st.Game_State, pls: ^st.Player_State, ps: ^st.Physics_State, delta_time: f32, elapsed_time: f32) {
    st.clear_physics_state(ps)

    filter: bit_set[enm.Level_Geometry_Component_Name; u64] = { .Collider, .Transform }
    ppos := pls.position
    ppos32: [3]f32 = {f32(ppos[0]), f32(ppos[1]), f32(ppos[2])}
    px, py, pz := f32(ppos[0]), f32(ppos[1]), f32(ppos[2])
    player_sq_radius := f32(const.SPHERE_RADIUS * const.SPHERE_RADIUS)
    player_velocity := pls.velocity * delta_time
    player_velocity_len := la.length(player_velocity)
    end_ppos := ppos32 + player_velocity

    got_contact_ray_col := false

    transformed_coll_vertices := ps.static_collider_vertices

    tv_offset := 0

    for lg, id in gs.level_geometry {
        coll := ps.level_colliders[lg.collider] 
        if filter <= lg.attributes {
            vertices := transformed_coll_vertices[tv_offset:tv_offset + len(coll.vertices)] 
            aabb := lg.aabb

            total : f32 = 0
            if px < lg.aabb.x0 do total += (px - lg.aabb.x0) * (px - lg.aabb.x0)
            if px > lg.aabb.x1 do total += (px - lg.aabb.x1) * (px - lg.aabb.x1)
            if py < lg.aabb.y0 do total += (py - lg.aabb.y0) * (py - lg.aabb.y0)
            if py > lg.aabb.y1 do total += (py - lg.aabb.y1) * (py - lg.aabb.y1)
            if pz < lg.aabb.z0 do total += (pz - lg.aabb.z0) * (pz - lg.aabb.z0)
            if pz > lg.aabb.z1 do total += (pz - lg.aabb.z1) * (pz - lg.aabb.z1)

            if total < player_sq_radius {
                // got player within bounding box
                l := len(coll.indices)
                for i := 0; i <= l - 3; i += 3 {
                    tri_indices := coll.indices[i:i+3]
                    tri_vertex0 := vertices[tri_indices[0]]
                    tri_vertex1 := vertices[tri_indices[1]]
                    tri_vertex2 := vertices[tri_indices[2]]
                    velocity_normal := la.normalize(pls.velocity)
                    normal, plane_dist := triangle_normal_dist(tri_vertex0, tri_vertex1, tri_vertex2)
                    if la.dot(normal, velocity_normal) <= 0 {
                        intercept_t: f32
                        intercept_pt: [3]f32
                        did_intercept := false
                        if intercept_pt, did_intercept = sphere_intersects_plane(ppos32, const.SPHERE_RADIUS, normal, plane_dist); did_intercept {
                            intercept_t = 0
                        } else {
                            sphere_contact_pt := ppos32 - normal * const.SPHERE_RADIUS
                            intercept_t, intercept_pt, did_intercept = ray_plane_intersection(sphere_contact_pt, player_velocity, normal, plane_dist);
                        }
                        if did_intercept {
                            if pt_inside_triangle(tri_vertex0, tri_vertex1, tri_vertex2, intercept_pt) {
                                pls.bunny_hop_y = max(f32)
                                append(&ps.collisions, typ.Collision{
                                    id = id,
                                    normal = normal,
                                    contact_dist = 0,
                                    plane_dist = plane_dist,
                                    t = intercept_t
                                }) 
                            } else {
                                tri_edges: [][2][3]f32 = {{tri_vertex0, tri_vertex1}, {tri_vertex0, tri_vertex2}, {tri_vertex1, tri_vertex2}}
                                lowest_edge_t: f32 = 1.1
                                for edge in tri_edges {
                                    edge_t, edge_hit := intersect_segment_cylinder(ppos32, end_ppos, edge[0], edge[1], const.SPHERE_RADIUS)
                                    if edge_hit && edge_t <= 1 {
                                        lowest_edge_t = min(lowest_edge_t, edge_t)
                                    }
                                }
                                if lowest_edge_t <= 1 {
                                    append(&ps.collisions, typ.Collision{
                                        id = id,
                                        normal = normal,
                                        contact_dist = 0, // figure out if we should keep this
                                        plane_dist = plane_dist,
                                        t = lowest_edge_t
                                    })
                                } else {
                                    lowest_vertex_t: f32 = 1.1
                                    tri_vertices := [][3]f32 { tri_vertex0, tri_vertex1, tri_vertex2 }
                                    for vertex in tri_vertices {
                                        if vertex_t, coll_pt, sphere_hit := ray_sphere_intersect(vertex, -velocity_normal, ppos32); sphere_hit {
                                            if vertex_t = vertex_t / player_velocity_len; vertex_t <= 1 {
                                                lowest_vertex_t = min(lowest_vertex_t, vertex_t)
                                            }
                                        }
                                    }
                                    if lowest_vertex_t <= 1 {
                                        pls.bunny_hop_y = max(f32)
                                        append(&ps.collisions, typ.Collision{
                                            id = id,
                                            normal = normal,
                                            contact_dist = 0, // figure out if we should keep this
                                            plane_dist = plane_dist,
                                            t = lowest_vertex_t
                                        })
                                    }
                                }
                            }
                        }
                    }
                    if plane_t, plane_q, plane_hit := ray_plane_intersection(ppos32, pls.contact_ray, normal, plane_dist); plane_hit {
                        closest_pt := closest_triangle_pt(tri_vertex0, tri_vertex1, tri_vertex2, plane_q)
                        if la.length2(closest_pt - plane_q) < const.GROUNDED_RADIUS2 {
                            got_contact_ray_col = true
                        }
                    }
                }
            }
        }         
        tv_offset += len(coll.vertices)
    }

    p_state := pls.state
    if (p_state == .ON_GROUND || p_state == .ON_WALL || p_state == .ON_SLOPE) && !got_contact_ray_col {
        pls.state = .IN_AIR
    }
    if p_state == .ON_GROUND {
        pls.left_ground = elapsed_time
    }
    if p_state == .ON_SLOPE {
        pls.left_slope = elapsed_time
    }
    if p_state == .ON_WALL {
        pls.left_wall = elapsed_time
    }

    best_plane_normal: [3]f32 = {100, 100, 100}
    most_horizontal_coll: typ.Collision = {} 
    //best_plane_intersection: [3]f32 = {0, 0, 0}
    for coll in ps.collisions {
        contact_ray := -coll.normal * player_velocity_len
        //plane_t, plane_q, plane_ok := ray_plane_intersection(ppos32, contact_ray, coll.normal, coll.plane_dist);
        //if plane_ok && la.length2(coll.closest_pt - plane_q) < const.GROUNDED_RADIUS2 {
        if coll.contact_dist < const.GROUNDED_RADIUS2 {
            // ground_ray close enough to surface
            if abs(coll.normal.y) < best_plane_normal.y {
                best_plane_normal = coll.normal
                most_horizontal_coll = coll 
                //best_plane_intersection = plane_q
            }
        }
    }
    if best_plane_normal.y < 100.0 {
        // the most horizontal surface
        ground_x := [3]f32{1, 0, 0}
        ground_z := [3]f32{0, 0, -1}
        if best_plane_normal.y >= 0.85{
            if pls.state != .ON_GROUND {
                pls.touch_pt = pls.position - {0, 0, 0.5}
                pls.touch_time = elapsed_time
            }
            //pls.position = best_plane_intersection + best_plane_normal * GROUND_OFFSET 
            pls.ground_x = la.normalize(ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal)
            pls.ground_z = la.normalize(ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal)
            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
            pls.state = .ON_GROUND
        } else if .2 <= best_plane_normal.y && best_plane_normal.y < .85 {
            if pls.state != .ON_SLOPE {
                pls.touch_pt = pls.position - {0, 0, 0.5}
                pls.touch_time = elapsed_time
                pls.ground_x = ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal
                pls.ground_z = ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal
                pls.state = .ON_SLOPE
            }
            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
        } else if best_plane_normal.y < .2 && pls.state != .ON_GROUND {
            if pls.state != .ON_WALL {
                pls.touch_pt = pls.position - {0, 0, 0.5}
                pls.touch_time = elapsed_time
            }
            pls.state = .ON_WALL
            pls.contact_ray = -best_plane_normal * const.GROUND_RAY_LEN
        }
    }
}


sphere_intersects_plane :: proc(c: [3]f32, r: f32, plane_norm: [3]f32, plane_dist: f32) -> (intersect_pt: [3]f32, did_intercept: bool) {
    dist := la.dot(c, plane_norm) - plane_dist
    return c - dist * plane_norm, abs(dist) < r
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

triangle_normal_dist :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32) -> (plane_normal: [3]f32, plane_dist: f32) {
    plane_normal = la.normalize(la.cross(t1 - t0, t2 - t0)) // normal
    plane_dist = la.dot(plane_normal, t0)
    return
}

pt_inside_triangle :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32, p: [3]f32) -> bool {
    a, b, c := t0 - p, t1 - p, t2 - p
    u, v, w := la.cross(b, c), la.cross(c, a), la.cross(a, b)
    if la.dot(u, v) >= 0 && la.dot(u, w) >= 0 {
        return true
    }
    return false
}

closest_triangle_edge_pt :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32, p: [3]f32) -> [3]f32 {
    t01_pt := closest_line_pt(t0, t1, p)
    t12_pt := closest_line_pt(t1, t2, p)
    t20_pt := closest_line_pt(t2, t0, p)
    t01_len2 := la.length2(t01_pt - p)
    t12_len2 := la.length2(t12_pt - p)
    t20_len2 := la.length2(t20_pt - p)
    min := min(t01_len2, t12_len2, t20_len2)
    if min == t01_len2 {
        return t01_pt
    }
    if min == t12_len2 {
        return t12_pt
    }
    if min == t20_len2 {
        return t20_pt
    }
    return {0, 0, 0}
}

// returns closest pt, plane normal and plane distance from origin (scalar)
closest_triangle_pt :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32, p: [3]f32) -> [3]f32  {
    a, b, c := t0, t1, t2
    a -= p 
    b -= p
    c -= p
    u, v, w := la.cross(b, c), la.cross(c, a), la.cross(a, b)
    if la.dot(u, v) >= 0 && la.dot(u, w) >= 0 {
        return p
    }
    return closest_triangle_edge_pt(t0, t1, t2, p)
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
    c := la.dot(m, m) - const.SPHERE_SQ_RADIUS
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

closest_segment_pts :: proc(p1: [3]f32, q1: [3]f32, p2: [3]f32, q2: [3]f32) -> (c1: [3]f32, c2: [3]f32, dist: f32) {
    d1 := q1 - p1
    d2 := q2 - p2
    r := p1 - p2
    s, t: f32
    a := la.dot(d1, d1)
    e := la.dot(d2, d2)
    f := la.dot(d2, r)
    if a < la.F32_EPSILON && e < la.F32_EPSILON{
        c1 = p1
        c2 = p2
        dist = la.dot(c1 - c2, c1 - c2)
        return
    }
    if a <= la.F32_EPSILON {
        s = 0
        t = clamp(f / e, 0, 1)
    } else {
        c := la.dot(d1, r)
        if e <= la.F32_EPSILON {
            t = 0
            s = clamp(-c / a, 0, 1)
        } else {
            b := la.dot(d1, d2)
            denom := a * e - b * b
            if denom != 0 {
                s = clamp((b * f - c * e) / denom, 0, 1)
            } else {
                s = 0
            }
            t = (b * s + f) / e
            if t < 0 {
                t = 0
                s = clamp(-c / a, 0, 1)
            } else if t > 1 {
                t = 1
                s = clamp((b - c) / a, 0, 1)
            }
        }
    }
    c1 = p1 + d1 * s
    c2 = p2 + d2 * t
    dist = la.dot(c1 - c2, c1 - c2)
    return
}

closest_triangle_pt_3d :: proc(p: [3]f32, a: [3]f32, b: [3]f32, c: [3]f32) -> [3]f32 {
    ab := b - a
    ac := c - a
    ap := p - a
    d1 := la.dot(ab, ap)
    d2 := la.dot(ac, ap)
    if d1 <= 0 && d2 <= 0 {
        return a
    }
    bp := p - b
    d3 := la.dot(ab, bp)
    d4 := la.dot(ac, bp)
    if d3 >= 0 && d4 <= d3 {
        return b
    }
    vc := d1 * d4 - d3 * d2 
    if vc <= 0 && d1 >= 0 && d3 <= 0 {
        v := d1 / (d1 - d3)
        return a + v * ab
    }
    cp := p - c
    d5 := la.dot(ab, cp)
    d6 := la.dot(ac, cp)
    if d6 >= 0 && d5 <= d6 {
        return c
    }
    vb := d5 * d2 - d1 * d6
    if vb <= 0 && d2 >= 0 && d6 <= 0 {
        w := d2 / (d2 - d6)
        return a + w * ac
    }
    va := d3 * d6 - d5 * d4
    if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
        w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return b + w * (c - b)
    }
    denom := 1 / (va + vb + vc)
    v := vb * denom
    w := vc * denom
    return a + ab * v + ac * w
}

closest_triangle_connection :: proc(a: [3]f32, b: [3]f32, c: [3]f32, x: [3]f32, y: [3]f32, z:[3]f32) -> (s0: [3]f32, s1: [3]f32, shortest_dist := max(f32)) {
    // shortest_dist := max(f32)
    abc := [3][3]f32{a, b, c}
    xyz := [3][3]f32{x, y, z}
    segs0 := [3][2][3]f32{
        {a, b},
        {b, c},
        {a, c}
    }
    segs1 := [3][2][3]f32{
        {x, y},
        {y, z},
        {x, z}
    }
    for v0 in abc {
        pt := closest_triangle_pt_3d(v0, x, y, z)
        dist := la.length2(pt - v0)
        if dist < shortest_dist {
            shortest_dist = dist
            s0 = v0
            s1 = pt
        }
    }
    for v1 in xyz {
        pt := closest_triangle_pt_3d(v1, a, b, c)
        dist := la.length2(pt - v1)
        if dist < shortest_dist {
            shortest_dist = dist
            s0 = pt 
            s1 = v1
        }
        
    }
    for seg0 in segs0 {
        for seg1 in segs1 {
            c0, c1, dist := closest_segment_pts(seg0[0], seg0[1], seg1[0], seg1[1])
            if dist < shortest_dist {
                shortest_dist = dist
                s0 = c0
                s1 = c1
            }
        }
    }
    return
}

intersect_segment_cylinder :: proc(sa: [3]f32, sb: [3]f32, p: [3]f32, q: [3]f32, r: f32) -> (t: f32, intersected: bool) {
    d := q - p 
    m := sa - p
    n := sb - sa
    md := la.dot(m, d)
    nd := la.dot(n, d)
    dd := la.dot(d, d)
    // segment outside p side
    if md < 0 && md + nd < 0   { return 0, false }
    // segment outside q side
    if md > dd && md + nd > dd { return 0, false }
    nn := la.dot(n, n)
    mn := la.dot(m, n)
    a := dd * nn - nd * nd
    k := la.dot(m, m) - r * r
    c := dd * k - md * md
    // segment parallel to cylinder axis
    if math.abs(a) < math.F32_EPSILON {
        if c > 0 { return 0, false }
        if md < 0 {
            t = -mn / nn
        } else if md > dd {
            t = (nd - mn) / nn
        } else {
            t = 0
        }
        intersected = true
        return
    }
    b := dd * mn - nd * md 
    discr := b * b - a * c
    if discr < 0 { return 0, false }
    t = (-b - math.sqrt(discr)) / a
    // intersection outside segment
    if t < 0 || t > 1 { return 0, false }
    intersected = true 
    return
}



