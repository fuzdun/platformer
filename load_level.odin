package main

import la "core:math/linalg"
import "core:encoding/cbor"
import "core:os"
import "core:math"
import "core:fmt"
import "base:runtime"
import vmem "core:mem/virtual"
import rnd "core:math/rand"
import str "core:strings"
import glm "core:math/linalg/glsl"

trim_bit_set :: proc(bs: bit_set[$T; u64]) -> (out: bit_set[T; u64]){
    for val in T {
        if val in bs {
            out += {val}
        }
    }
    return
}

encode_test_level_cbor :: proc(lgs: #soa[]Level_Geometry) {
    aos_level_data := make([dynamic]Level_Geometry, context.temp_allocator)
    for &lg in lgs {
        lg.attributes = {.Collider, .Crackable}
        append(&aos_level_data, lg)
    }
    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_geometry :: proc(filename: string, arena: runtime.Allocator) -> []Level_Geometry {
    level_filename := str.concatenate({"levels/", filename, ".bin"}, context.temp_allocator)
    level_bin, read_err := os.read_entire_file(level_filename, context.temp_allocator)
    decoded, decode_err := cbor.decode(string(level_bin), nil, context.temp_allocator)
    decoded_arr := decoded.(^cbor.Array)
    loaded_level_geometry: []Level_Geometry

    if PERF_TEST {
        // perf test load======================
        loaded_level_geometry = make([]Level_Geometry, 1000, arena)
        for i in 0..< 1000 {
            rot := la.quaternion_from_euler_angles_f32(rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, .XYZ)
            lg: Level_Geometry
            lg.shape = .CUBE
            lg.collider = .CUBE

            x := f32(i % 10)
            y := math.floor(f32(i) / 4) - 50
            lg.transform = {{x * 120, y * 1 - 80, y * -45 + 200},{40, 40, 40}, rot}
            lg.render_type = .Standard
            lg.attributes = { .Collider }
            loaded_level_geometry[i] = lg
        }
    } else {
        // standard load from level data=============
        loaded_level_geometry = make([]Level_Geometry, len(decoded_arr), arena)
        for entry, idx in decoded_arr {
            // decode level geometry struct
            lg: Level_Geometry
            entry_bin, _ := cbor.encode(entry, cbor.ENCODE_SMALL, context.temp_allocator)
            cbor.unmarshal(string(entry_bin), &lg)
            lg.attributes = trim_bit_set(lg.attributes)
            lg.transparency = 1.0
            if lg.shape == .DASH_BARRIER {
                lg.attributes += {.Hazardous, .Dash_Breakable, .Breakable}
                lg.render_type = .Dash_Barrier
            } else if lg.shape == .SLIDE_ZONE {
                lg.attributes += {.Hazardous, .Slide_Zone, .Breakable}
                lg.render_type = .Slide_Zone
            } else if lg.shape == .BOUNCY {
                lg.attributes += {.Bouncy}
                lg.render_type = .Bouncy
            } else if lg.shape == .ICE_CREAM || lg.shape == .CHAIR {
                lg.attributes -= {.Collider}
                lg.render_type = .Wireframe
            }
            loaded_level_geometry[idx] = lg
        }
    }
    return loaded_level_geometry
}

add_geometry_to_physics :: proc(ps: ^Physics_State, szs: ^Slide_Zone_State, lgs_in: #soa[]Level_Geometry) {
    for &lg, lg_idx in lgs_in {
        if .Collider not_in lg.attributes {
            continue
        }
        rot_mat := glm.mat4FromQuat(lg.transform.rotation)
        vertices_len := len(ps.level_colliders[lg.shape].vertices)
        transformed_vertices := make([][3]f32, vertices_len)
        defer delete(transformed_vertices)
        if lg.shape == .SLIDE_ZONE {
            sz: Obb
            sz.id = lg_idx
            x := rot_mat * [4]f32{1, 0, 0, 0}
            y := rot_mat * [4]f32{0, 1, 0, 0}
            z := rot_mat * [4]f32{0, 0, 1, 0}
            sz.axes = {x.xyz, y.xyz, z.xyz}
            sz.dim = lg.transform.scale 
            sz.center = lg.transform.position
            append(&szs.entities, sz)
        }
        trans_mat := trans_to_mat4(lg.transform)
        for v, vi in ps.level_colliders[lg.shape].vertices {
            transformed_vertices[vi] = (trans_mat * [4]f32{v[0], v[1], v[2], 1.0}).xyz
        }
        lg.aabb = vertices_to_aabb(transformed_vertices)
        lg.physics_idx = len(ps.static_collider_vertices)
        append(&ps.static_collider_vertices, ..transformed_vertices)
    }
}

vertices_to_aabb :: proc(vertices: [][3]f32) -> Aabb {
    aabbx0, aabby0, aabbz0 := max(f32), max(f32), max(f32)
    aabbx1, aabby1, aabbz1 := min(f32), min(f32), min(f32)
    for v in vertices {
        aabbx0 = min(v.x - 10, aabbx0)
        aabby0 = min(v.y - 10, aabby0)
        aabbz0 = min(v.z - 10, aabbz0)
        aabbx1 = max(v.x + 10, aabbx1)
        aabby1 = max(v.y + 10, aabby1)
        aabbz1 = max(v.z + 10, aabbz1)
    }
    return {aabbx0, aabby0, aabbz0, aabbx1, aabby1, aabbz1}
}

