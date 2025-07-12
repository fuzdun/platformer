package main

import "core:math"
import la "core:math/linalg"


Physics_State :: struct{
    //collisions: [dynamic]typ.Collision,
    debug_render_queue: struct {
        vertices: [dynamic]Vertex,
        indices: [ProgramName][dynamic]u16
    },
    level_colliders: [SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
}

clear_physics_state :: proc(ps: ^Physics_State) {
    //clear(&ps.collisions)
    clear(&ps.debug_render_queue.vertices)
    for &iq in ps.debug_render_queue.indices {
        clear(&iq)
    }
}

free_physics_state :: proc(ps: ^Physics_State) {
    //delete(ps.collisions)
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


Collision :: struct{
    id: int,
    normal: [3]f32,
    t: f32
}

Collider_Data :: struct{
    vertices: [][3]f32,
    indices: []u16
}

player_lg_collision :: proc(c0: [3]f32, r: f32, t0: [3]f32, t1: [3]f32, t2: [3]f32, v: [3]f32, v_l: f32, v_n: [3]f32, c1: [3]f32, cr: [3]f32, gr: f32
) -> (collided: bool = false, collision_t: f32, collision_n: [3]f32, contact: bool = false) {
    p_normal, p_dist := triangle_plane(t0, t1, t2)
    collision_n = p_normal
    if la.dot(p_normal, v_n) <= 0 {
        intercept_t: f32
        intercept_pt: [3]f32
        did_intercept := false
        if intercept_pt, did_intercept = sphere_plane_intersection(c0, r, p_normal, p_dist); did_intercept {
            intercept_t = 0
        } else {
            sphere_contact_pt := c0 - p_normal * r
            intercept_t, intercept_pt, did_intercept = ray_plane_intersection(sphere_contact_pt, v, p_normal, p_dist);
        }
        if did_intercept {
            if pt_inside_triangle(t0, t1, t2, intercept_pt) {
                // collision with triangle face
                collided = true
                collision_t = intercept_t
            } else {
                tri_edges: [][2][3]f32 = {{t0, t1}, {t0, t2}, {t1, t2}}
                lowest_edge_t: f32 = 1.1
                for edge in tri_edges {
                    if edge_t, edge_hit := segment_cylinder_intersection(c0, c1, edge[0], edge[1], r); edge_hit {
                        lowest_edge_t = min(lowest_edge_t, edge_t)
                    }
                }
                if lowest_edge_t <= 1 {
                    // collision with triangle edge
                    collided = true
                    collision_t = lowest_edge_t
                } else {
                    lowest_vertex_t: f32 = 1.1
                    tri_vertices := [][3]f32 { t0, t1, t2 }
                    for vertex in tri_vertices {
                        if vertex_t, coll_pt, vertex_hit := ray_sphere_intersection(vertex, -v_n, c0); vertex_hit {
                            lowest_vertex_t = min(lowest_vertex_t, vertex_t / v_l)
                        }
                    }
                    if lowest_vertex_t <= 1 {
                        // collision with triangle edge
                        collided = true
                        collision_t = lowest_vertex_t
                    }
                }
            }
        }
    }
    if _, plane_intersection_pt, intersected_plane := ray_plane_intersection(c0, cr, p_normal, p_dist); intersected_plane {
        closest_pt := closest_triangle_pt(t0, t1, t2, plane_intersection_pt)
        if la.length2(closest_pt - plane_intersection_pt) < gr {
            contact = true
        }
    }
    return
}

sphere_aabb_collision :: proc(c: [3]f32, r: f32, aabb: Aabb) -> bool {
    total : f32 = 0
    if c.x < aabb.x0 do total += (c.x - aabb.x0) * (c.x - aabb.x0)
    if c.x > aabb.x1 do total += (c.x - aabb.x1) * (c.x - aabb.x1)
    if c.y < aabb.y0 do total += (c.y - aabb.y0) * (c.y - aabb.y0)
    if c.y > aabb.y1 do total += (c.y - aabb.y1) * (c.y - aabb.y1)
    if c.z < aabb.z0 do total += (c.z - aabb.z0) * (c.z - aabb.z0)
    if c.z > aabb.z1 do total += (c.z - aabb.z1) * (c.z - aabb.z1)
    return total < r 
}

sphere_plane_intersection :: proc(c: [3]f32, r: f32, plane_norm: [3]f32, plane_dist: f32) -> (intersect_pt: [3]f32, did_intercept: bool) {
  dist := la.dot(c, plane_norm) - plane_dist
  return c - dist * plane_norm, abs(dist) < r
}

ray_plane_intersection :: proc(start: [3]f32, offset: [3]f32, plane_n: [3]f32, plane_d: f32) -> (t: f32, q: [3]f32, ok: bool) {
  t = (plane_d - la.dot(plane_n, start)) / la.dot(plane_n, offset) 
  if t >= 0 && t <= 1 {
    q = start + t * offset
        ok = true
        return
    }
    ok = false
    return
}

triangle_plane :: proc(t0: [3]f32, t1: [3]f32, t2: [3]f32) -> (plane_normal: [3]f32, plane_dist: f32) {
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

ray_sphere_intersection :: proc(origin: [3]f32, dir: [3]f32, ppos: [3]f32) -> (t: f32, q: [3]f32, ok: bool) {
    m := origin - ppos 
    b := la.dot(m, dir)
    c := la.dot(m, m) - PLAYER_SPHERE_SQ_RADIUS
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

segment_cylinder_intersection :: proc(sa: [3]f32, sb: [3]f32, p: [3]f32, q: [3]f32, r: f32) -> (t: f32, intersected: bool) {
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

