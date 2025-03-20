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
    for lg in lgs {
        append(&aos_level_data, lg)
    }

    //rotation : quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
    //shallow_angle: Level_Geometry
    //shallow_angle.shape = "basic_cube"
    //shallow_angle.collider = "basic_cube"
    //shallow_angle.transform = {{0, 0, 0},{10, 10, 10}, rotation}
    //shallow_angle.shaders = {.Trail}
    //shallow_angle.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
    //append(&aos_level_data, shallow_angle)
    //
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

    //for entry in decoded.(^cbor.Array) {
    //    lg: Level_Geometry
    //    entry_bin, _ := cbor.encode(entry)
    //    defer delete(entry_bin)
    //    cbor.unmarshal(string(entry_bin), &lg)
    //    lg.attributes = trim_bit_set(lg.attributes)
    //    lg.shaders = trim_bit_set(lg.shaders)
    //    trns := lg.transform
    //    coll_vertices := ps.level_colliders[SHAPE_NAMES[lg.collider]].vertices
    //    transformed_coll_vertices := make([][3]f32, len(coll_vertices)); defer delete(transformed_coll_vertices)
    //    for v, vi in coll_vertices {
    //        transformed_coll_vertices[vi] = la.quaternion128_mul_vector3(trns.rotation, trns.scale * v) + trns.position
    //    }
    //    append(&ps.static_collider_vertices, ..transformed_coll_vertices[:])
    //    lg.aabb = construct_aabb(transformed_coll_vertices)
    //    append(&gs.level_geometry, lg)
    //}
    //fmt.println(rs.render_group_offsets)

    for i in 0..<100 {
        rot := la.quaternion_from_euler_angles_f32(rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, rnd.float32() * .5 - .25, .XYZ)
        //rotation : quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
        shape: SHAPES = i % 2 == 0 ? .CUBE : .WEIRD 
        //shape_name := SHAPE_NAMES[shape]
        shader: ProgramName = i % 3 == 0 ? .Simple : .Trail
        shallow_angle: Level_Geometry
        shallow_angle.shape = shape
        shallow_angle.collider = shape

        x := f32(i % 20)
        y := math.floor(f32(i) / 10.0)
        shallow_angle.transform = {{x * 10, y * -2 -20, y * -10 + 300},{10, 10, 10}, rot}
        shallow_angle.shaders = {shader}
        shallow_angle.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
        vertices := ps.level_colliders[shape].vertices
        trns := shallow_angle.transform
        transformed_vertices := make([][3]f32, len(vertices)); defer delete(transformed_vertices)
        for v, vi in vertices {
            transformed_vertices[vi] = la.quaternion128_mul_vector3(trns.rotation, trns.scale * v) + trns.position
        }

        //offset_idx := min(len(rs.render_group_offsets) - 1, int(shader) * len(ProgramName) + int(shape) + 1)
        //inject_at(&ps.static_collider_vertices, offset_idx)
        //inject_at(&gs.level_geometry, offset_idx)

        append(&ps.static_collider_vertices, ..transformed_vertices[:])
        shallow_angle.aabb = construct_aabb(transformed_vertices)
        append(&gs.level_geometry, shallow_angle)


        //for &offset, idx in rs.render_group_offsets {
        //    if idx >= offset_idx {
        //       offset += 1 
        //    }
        //}
    }
}

