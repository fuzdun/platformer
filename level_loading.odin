package main

import la "core:math/linalg"
import "core:encoding/cbor"
import "core:fmt"
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

    //rot := la.quaternion_from_euler_angles_f32(0, 0, 0, .XYZ)
    //lg: Level_Geometry
    //lg.shape = .CUBE
    //lg.collider = .CUBE
    //lg.shaders = {.Trail}
    //lg.transform = {{0, 0, 0},{10, 10, 10}, rot}
    //lg.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
    //append(&aos_level_data, lg)

    for lg in lgs {
        append(&aos_level_data, lg)
    }

    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC)
    defer delete(bin)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_geometry :: proc(gs: ^Game_State, ps: ^Physics_State, rs: ^Render_State, filename: string) {
    clear_soa(&gs.level_geometry)
    level_filename := str.concatenate({"levels/", filename, ".bin"})
    defer delete(level_filename)
    level_bin, read_err := os.read_entire_file(level_filename)
    defer delete(level_bin)
    decoded, decode_err := cbor.decode(string(level_bin))
    defer cbor.destroy(decoded)

    for entry in decoded.(^cbor.Array) {
        // decode level geometry struct
        lg: Level_Geometry
        entry_bin, _ := cbor.encode(entry)
        defer delete(entry_bin)
        cbor.unmarshal(string(entry_bin), &lg)
        lg.attributes = trim_bit_set(lg.attributes)
        lg.shaders = trim_bit_set(lg.shaders)

        process_and_add_geometry(gs, rs, ps, lg)
    }
    //for i in 0..<500 {
    //
    //    rot := la.quaternion_from_euler_angles_f32(rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, .XYZ)
    //    //shape: SHAPES = rnd.choice([]SHAPES{.CUBE, .WEIRD})
    //    //shader: ProgramName = rnd.choice([]ProgramName{.Trail, .Simple})
    //    shape: SHAPES = .CUBE
    //    shader: ProgramName = .Simple
    //    shallow_angle: Level_Geometry
    //    shallow_angle.shape = shape
    //    shallow_angle.collider = shape
    //
    //    x := f32(i % 10)
    //    y := math.floor(f32(i) / 10.0)
    //    shallow_angle.transform = {{x * 20, y * -2 -20, y * -10 + 300},{10, 10, 10}, rot}
    //    shallow_angle.shaders = {shader}
    //    shallow_angle.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
    //
    //    process_and_add_geometry(gs, rs, ps, &shallow_angle)
    //}
}

process_and_add_geometry :: proc(gs: ^Game_State, rs: ^Render_State, ps: ^Physics_State, lg_in: Level_Geometry) {
    lg := lg_in
    // reset ssbo_indexes
    for &idx in lg.ssbo_indexes {
        idx = -1 
    }

    // construct aabb and add transformed vertices to physics state
    vertices := ps.level_colliders[lg.shape].vertices
    transformed_vertices := make([][3]f32, len(vertices)); defer delete(transformed_vertices)
    trns := lg.transform
    trans_mat := trans_to_mat4(lg.transform)
    max_z := min(f32)
    min_z := max(f32)
    for v, vi in vertices {
        tv := trans_mat * [4]f32{v[0], v[1], v[2], 1.0}
        max_z = max(tv.z, max_z)
        min_z = min(tv.z, min_z)
        transformed_vertices[vi] = tv.xyz
    }
    lg.aabb = construct_aabb(transformed_vertices)
    append(&ps.static_collider_vertices, ..transformed_vertices)

    // insert transform into render state
    for shader in lg.shaders {
        last_offsets_idx := len(rs.render_group_offsets) - 1
        group_offsets_idx := int(int(shader) * len(SHAPES) + int(lg.shape))
        in_last_group := group_offsets_idx == last_offsets_idx
        nxt_group_start_idx := in_last_group ? u32(len(rs.static_transforms)) : rs.render_group_offsets[group_offsets_idx + 1]

        inject_at(&rs.z_widths, nxt_group_start_idx, max_z - min_z)
        inject_at(&rs.static_transforms, nxt_group_start_idx, trans_mat)

        if EDIT {
            append(&gs.editor_state.ssbo_registry[group_offsets_idx], len(gs.level_geometry))
        }

        lg.ssbo_indexes[shader] = int(nxt_group_start_idx)

        for &g_offset, idx in rs.render_group_offsets[group_offsets_idx + 1:] {
            g_offset += 1 
        }
    }
    append(&gs.level_geometry, lg)
}


