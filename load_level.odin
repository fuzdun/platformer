package main

import la "core:math/linalg"
import "core:encoding/cbor"
import "core:os"
import "core:math"
import "core:fmt"
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

    for &lg in lgs.entities {
        lg.attributes = {.Collider, .Crackable}
        append(&aos_level_data, lg)
    }

    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC)
    defer delete(bin)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_geometry :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, ps: ^Physics_State, rs: ^Render_State, szs: ^Slide_Zone_State, filename: string) {
    level_filename := str.concatenate({"levels/", filename, ".bin"})
    defer delete(level_filename)
    level_bin, read_err := os.read_entire_file(level_filename)
    defer delete(level_bin)
    decoded, decode_err := cbor.decode(string(level_bin))
    defer cbor.destroy(decoded)
    decoded_arr := decoded.(^cbor.Array)
    clear(&lgs.entities)
    loaded_level_geometry: []Level_Geometry
    defer delete(loaded_level_geometry)

    if PERF_TEST {
        // perf test load======================
        loaded_level_geometry = make([]Level_Geometry, 1000)
        for i in 0..< 1000 {
            rot := la.quaternion_from_euler_angles_f32(rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, .XYZ)
            lg: Level_Geometry
            lg.shape = .CUBE
            lg.collider = .CUBE

            x := f32(i % 10)
            y := math.floor(f32(i) / 4)
            lg.transform = {{x * 120, y * 1 - 80, y * -45 + 200},{40, 40, 40}, rot}
            lg.render_type = .Standard
            lg.attributes = { .Collider }

            loaded_level_geometry[i] = lg
        }
        // =====================================
    } else if PLAYER_DRAW {
        loaded_level_geometry = make([]Level_Geometry, 1)
        rot := la.quaternion_from_euler_angles_f32(0, 0, 0, .XYZ)
        shape: SHAPE = .CUBE
        lg: Level_Geometry
        lg.shape = shape
        lg.collider = shape
        lg.transform = {{0, -1000, 0},{1000, 1000, 1000}, rot}
        lg.render_type = .Standard 
        lg.attributes = { .Collider }
        loaded_level_geometry[0] = lg
    } else {
        // standard load from level data=============
        loaded_level_geometry = make([]Level_Geometry, len(decoded_arr))
        for entry, idx in decoded_arr {
            // decode level geometry struct
            lg: Level_Geometry
            entry_bin, _ := cbor.encode(entry)
            defer delete(entry_bin)
            cbor.unmarshal(string(entry_bin), &lg)
            lg.attributes = trim_bit_set(lg.attributes)
            if lg.shape == .DASH_BARRIER {
                lg.attributes += {.Hazardous, .Dash_Breakable}
                lg.render_type = .Dash_Barrier
            } else if lg.shape == .SLIDE_ZONE {
                lg.attributes += {.Hazardous, .Slide_Zone}
                lg.render_type = .Dash_Barrier
            } else if lg.shape == .ICE_CREAM {
                lg.attributes -= {.Collider}
                lg.render_type = .Wireframe
            }
            loaded_level_geometry[idx] = lg
        }
    }
    add_geometry_to_physics(ps, szs, loaded_level_geometry)
    add_geometry_to_renderer(lgs, rs, ps, loaded_level_geometry)
}

editor_reload_level_geometry :: proc(lgs: ^Level_Geometry_State, sr: Shape_Resources, ps: ^Physics_State, rs: ^Render_State) {
    current_level_geometry := make([]Level_Geometry, len(lgs.entities))
    defer delete(current_level_geometry)
    for lg, idx in lgs.entities {
        current_level_geometry[idx] = lg
    }
    clear(&lgs.entities)
    add_geometry_to_renderer(lgs, rs, ps, current_level_geometry[:])
}

lg_get_transformed_collider_vertices :: proc(lg: Level_Geometry, trans_mat: matrix[4, 4]f32, ps: Physics_State, out: [][3]f32) {
    vertices := ps.level_colliders[lg.shape].vertices
    for v, vi in vertices {
        out[vi] = (trans_mat * [4]f32{v[0], v[1], v[2], 1.0}).xyz    
    }
}

add_geometry_to_physics :: proc(ps: ^Physics_State, szs: ^Slide_Zone_State, lgs_in: []Level_Geometry) {
    clear_physics_state(ps)
    for &lg in lgs_in {
        trans_mat := trans_to_mat4(lg.transform)
        vertices_len := len(ps.level_colliders[lg.shape].vertices)
        transformed_vertices := make([][3]f32, vertices_len);
        defer delete(transformed_vertices)
        if lg.shape == .SLIDE_ZONE {
            // fmt.println(lg.transform)
            // fmt.println(trans_mat)
            sz: Obb
            x := [3]f32{trans_mat[0][0], trans_mat[1][0], trans_mat[2][0]}
            y := [3]f32{trans_mat[0][1], trans_mat[1][1], trans_mat[2][1]}
            z := [3]f32{trans_mat[0][2], trans_mat[1][2], trans_mat[2][2]}
            sz.axes = {la.normalize0(x), la.normalize0(y), la.normalize0(z)}
            sz.dim = [3]f32{la.length(x), la.length(y), la.length(z)}
            sz.center = [3]f32{trans_mat[3][0], trans_mat[3][1], trans_mat[3][2]}
            append(szs, sz)
            // fmt.println(sz)
        }
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

add_geometry_to_renderer :: proc(lgs: ^Level_Geometry_State, rs: ^Render_State, ps: ^Physics_State, lgs_in: []Level_Geometry) {
    for &lg in lgs_in {
        trans_mat := trans_to_mat4(lg.transform)
        vertices_len := len(ps.level_colliders[lg.shape].vertices)
        // transformed_vertices := make([][3]f32, vertices_len);
        // defer delete(transformed_vertices)
        // lg_get_transformed_collider_vertices(lg, trans_mat, ps^, transformed_vertices[:])
        // max_z := min(f32)
        // min_z := max(f32)
        // for v, vi in transformed_vertices {
        //     max_z = max(v.z, max_z)
        //     min_z = min(v.z, min_z)
        // }
        // insert transform into render state
        // loaded_shaders: Active_Shaders = EDIT ? {.Editor_Geometry} : lg.shaders
        append(&lgs.entities, lg)
    }
}

