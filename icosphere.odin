package main

import "core:math"
import "base:runtime"
import la "core:math/linalg"

ICO_H_ANGLE :: math.PI / 180 * 72
ICO_V_ANGLE := math.atan(0.5)

add_player_sphere_data :: proc(vertices: ^[]Vertex, fill_indices: ^[]u32, outline_indices: ^[]u32, arena: runtime.Allocator) {
    temp_vertices := make([dynamic]Vertex, context.temp_allocator) 

    hedron_tmp_vertices: [12][3]f32
    hedron_tmp_indices := make([dynamic]int, context.temp_allocator)

    h_angle_1 := f32(-math.PI / 2 - ICO_H_ANGLE / 2)
    h_angle_2 := f32(-math.PI / 2)

    z := f32(CORE_RADIUS * math.sin(ICO_V_ANGLE))
    xy := f32(CORE_RADIUS * math.cos(ICO_V_ANGLE))

    hedron_tmp_vertices[0] = {0, 0, CORE_RADIUS}
    i0 := 0
    i5 := 11
    for i in 1..=5 {
        hedron_tmp_vertices[i] = {
            xy * math.cos(h_angle_1),
            xy * math.sin(h_angle_1),
            z
        }
        hedron_tmp_vertices[i + 5] = {
            xy * math.cos(h_angle_2),
            xy * math.sin(h_angle_2),
            -z
        }
        h_angle_1 += ICO_H_ANGLE
        h_angle_2 += ICO_H_ANGLE
    }
    hedron_tmp_vertices[11] = {0, 0, -CORE_RADIUS}

    for i in 0..<5 {
        i1 := i + 1
        i2 := i == 4 ? 1 : i + 2
        i3 := i + 6
        i4 := i == 4 ? 6 : i + 7
        append(&hedron_tmp_indices, i0, i1, i2, i1, i3, i2, i2, i3, i4, i3, i5, i4)
    }


    new_vs := make([dynamic]([4]f32), context.temp_allocator) // 4th float is for marking spikes
    for i := 0; i < len(hedron_tmp_indices); i += 3 {
        clear(&new_vs)
        v1 := hedron_tmp_vertices[hedron_tmp_indices[i]] 
        v2 := hedron_tmp_vertices[hedron_tmp_indices[i + 1]] 
        v3 := hedron_tmp_vertices[hedron_tmp_indices[i + 2]] 
        append(&new_vs, [4]f32{v1.x, v1.y, v1.z, 1})

        for j in 1..=ICOSPHERE_SUBDIVISION {
            t := f32(j) / f32(ICOSPHERE_SUBDIVISION)
            new_v0 := la.vector_slerp(v1, v2, t)
            new_v1 := la.vector_slerp(v1, v3, t)
            for k in 0..=j {

                spike := (j + k) % 3 == 0 ? 1.0 : 0.0
                new_v: [4]f32
                new_v.w = f32(spike)

                if k == 0 {
                    new_v.xyz = new_v0
                } else if k == j {
                    new_v.xyz = new_v1 
                } else {
                    new_v.xyz = la.vector_slerp(new_v0, new_v1, f32(k) / f32(j))
                }
                append(&new_vs, new_v) 
            }
        }
        for j in 1..=ICOSPHERE_SUBDIVISION {
            for k in 0..<j {
                i1 := int(math.floor((f32(j) - 1.0) * f32(j) / 2.0 + f32(k)))
                i2 := int(math.floor(f32(j) * (f32(j) + 1.0) / 2.0 + f32(k)))
                v1: Vertex = {
                    pos = new_vs[i1].xyz,
                    uv = {new_vs[i1].w, new_vs[i1].w},
                    normal = la.normalize(new_vs[i1].xyz)
                }
                v2: Vertex = {
                    pos = new_vs[i2].xyz,
                    uv = {new_vs[i2].w, new_vs[i2].w},
                    normal = la.normalize(new_vs[i2].xyz)
                }
                v3: Vertex = {
                    pos = new_vs[i2 + 1].xyz,
                    uv = {new_vs[i2 + 1].w, new_vs[i2 + 1].w},
                    normal = la.normalize(new_vs[i2 + 1].xyz)
                }
                append(&temp_vertices, v1, v2, v3)

                if k < (j - 1) {
                    i2 = i1 + 1
                    v2 = {
                        pos = new_vs[i2].xyz,
                        uv = {new_vs[i2].w, new_vs[i2].w},
                        normal = la.normalize(new_vs[i2].xyz)

                    }
                    append(&temp_vertices, v1, v3, v2)
                }
            } 
        }
    }

    fill_indices^ = make([]u32, len(temp_vertices), arena)
    outline_indices^ = make([]u32, len(temp_vertices) * 2, arena)

    for i in 0..<len(temp_vertices) {
        fill_indices[i] = u32(i)
    }
    for i := 0; i < len(temp_vertices); i += 3 {
        outline_indices[i * 2] = u32(i)
        outline_indices[i * 2 + 1] = u32(i + 1)
        outline_indices[i * 2 + 2] = u32(i + 1)
        outline_indices[i * 2 + 3] = u32(i + 2)
        outline_indices[i * 2 + 4] = u32(i + 2)
        outline_indices[i * 2 + 5] = u32(i)
    }

    vertices^ = make([]Vertex, len(temp_vertices), arena)
    copy(vertices^, temp_vertices[:])
}

