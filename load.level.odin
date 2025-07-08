package main

import la "core:math/linalg"
import "core:encoding/cbor"
import "core:os"
import "core:math"
import rnd "core:math/rand"
import str "core:strings"

trim_bit_set :: proc(bs: bit_set[$T; u64]) -> (out: bit_set[T; u64]){
    for val in T {
        if val in bs {
            out += {val}
        }
    }
    return
}

encode_test_level_cbor :: proc(lgs: ^Level_Geometry_State) {
    aos_level_data := make([dynamic]Level_Geometry)
    defer delete(aos_level_data)

    for lg in lgs.entities {
        append(&aos_level_data, lg)
    }

    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC)
    defer delete(bin)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_geometry :: proc(lgs: ^Level_Geometry_State, lrs: Level_Resources, ps: ^Physics_State, rs: ^Render_State, filename: string) {
    level_filename := str.concatenate({"levels/", filename, ".bin"})
    defer delete(level_filename)
    level_bin, read_err := os.read_entire_file(level_filename)
    defer delete(level_bin)
    decoded, decode_err := cbor.decode(string(level_bin))
    defer cbor.destroy(decoded)
    decoded_arr := decoded.(^cbor.Array)
    clear_soa(&lgs.entities)
    loaded_level_geometry: #soa[]Level_Geometry
    defer delete(loaded_level_geometry)

    if !PERF_TEST {
        // standard load from level data=============
        loaded_level_geometry = make(#soa[]Level_Geometry, len(decoded_arr))
        for entry, idx in decoded_arr {
            // decode level geometry struct
            lg: Level_Geometry
            entry_bin, _ := cbor.encode(entry)
            defer delete(entry_bin)
            cbor.unmarshal(string(entry_bin), &lg)
            lg.attributes = trim_bit_set(lg.attributes)
            lg.shaders = trim_bit_set(lg.shaders)
            loaded_level_geometry[idx] = lg
        }
        // ==========================================
    } else {
        // perf test load======================
        loaded_level_geometry = make(#soa[]Level_Geometry, 500)
        for i in 0..<500 {
            rot := la.quaternion_from_euler_angles_f32(rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, .XYZ)
            shape: SHAPE = .CUBE
            shader: ProgramName = .Trail
            lg: Level_Geometry
            lg.shape = shape
            lg.collider = shape

            x := f32(i % 10)
            y := math.floor(f32(i) / 10.0)
            lg.transform = {{x * 20, y * -2 -20, y * -10 + 300},{10, 10, 10}, rot}
            lg.shaders = {shader}
            lg.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}

            loaded_level_geometry[i] = lg
        }
        // =====================================
    }
    add_geometry_to_physics(ps, loaded_level_geometry)
    add_geometry_to_renderer(lgs, rs, ps, loaded_level_geometry)
}

editor_reload_level_geometry :: proc(lgs: ^Level_Geometry_State, lrs: Level_Resources, ps: ^Physics_State, rs: ^Render_State) {
    current_level_geometry := make(#soa[]Level_Geometry, len(lgs.entities))
    defer delete_soa(current_level_geometry)
    for lg, idx in lgs.entities {
        current_level_geometry[idx] = lg
    }
    clear_soa(&lgs.entities)
    clear_render_state(rs)
    add_geometry_to_renderer(lgs, rs, ps, current_level_geometry[:])
}

lg_get_transformed_collider_vertices :: proc(lg: Level_Geometry, trans_mat: matrix[4, 4]f32, ps: Physics_State, out: [][3]f32) {
    vertices := ps.level_colliders[lg.shape].vertices
    for v, vi in vertices {
        out[vi] = (trans_mat * [4]f32{v[0], v[1], v[2], 1.0}).xyz    
    }
}

add_geometry_to_physics :: proc(ps: ^Physics_State, lgs_in: #soa[]Level_Geometry) {
    clear_physics_state(ps)
    for &lg in lgs_in {
        trans_mat := trans_to_mat4(lg.transform)
        vertices_len := len(ps.level_colliders[lg.shape].vertices)
        transformed_vertices := make([][3]f32, vertices_len);
        defer delete(transformed_vertices)
        lg_get_transformed_collider_vertices(lg, trans_mat, ps^, transformed_vertices[:])

        aabbx0, aabby0, aabbz0 := max(f32), max(f32), max(f32)
        aabbx1, aabby1, aabbz1 := min(f32), min(f32), min(f32)
        for v in transformed_vertices {
            aabbx0 = min(v.x - 10, aabbx0)
            aabby0 = min(v.y - 10, aabby0)
            aabbz0 = min(v.z - 10, aabbz0)
            aabbx1 = max(v.x + 10, aabbx1)
            aabby1 = max(v.y + 10, aabby1)
            aabbz1 = max(v.z + 10, aabbz1)
        }
        lg.aabb = {aabbx0, aabby0, aabbz0, aabbx1, aabby1, aabbz1}
        append(&ps.static_collider_vertices, ..transformed_vertices)
    }
}

add_geometry_to_renderer :: proc(lgs: ^Level_Geometry_State, rs: ^Render_State, ps: ^Physics_State, lgs_in: #soa[]Level_Geometry) {
    // initialize ssbo_indexes
    clear_render_state(rs)
    for &lg in lgs_in {
        for &idx in lg.ssbo_indexes {
            idx = -1 
        }
        trans_mat := trans_to_mat4(lg.transform)
        vertices_len := len(ps.level_colliders[lg.shape].vertices)
        transformed_vertices := make([][3]f32, vertices_len);
        defer delete(transformed_vertices)
        lg_get_transformed_collider_vertices(lg, trans_mat, ps^, transformed_vertices[:])
        max_z := min(f32)
        min_z := max(f32)
        for v, vi in transformed_vertices {
            max_z = max(v.z, max_z)
            min_z = min(v.z, min_z)
        }
        // insert transform into render state
        loaded_shaders: Active_Shaders = EDIT ? {.Simple} : lg.shaders
        for shader in loaded_shaders {
            group_offsets_idx := int(shader) * len(SHAPE) + int(lg.shape)
            group_start_idx := rs.render_group_offsets[group_offsets_idx]
            in_last_group := group_offsets_idx == len(rs.render_group_offsets) - 1
            nxt_group_start_idx := in_last_group ? u32(len(rs.static_transforms)) : rs.render_group_offsets[group_offsets_idx + 1]

            inject_at(&rs.z_widths, nxt_group_start_idx, max_z - min_z)
            inject_at(&rs.static_transforms, nxt_group_start_idx, trans_mat)

            lg.ssbo_indexes[shader] = int(nxt_group_start_idx - group_start_idx)

            for &g_offset, idx in rs.render_group_offsets[group_offsets_idx + 1:] {
                g_offset += 1 
            }
        }
        append(&lgs.entities, lg)
    }
}

