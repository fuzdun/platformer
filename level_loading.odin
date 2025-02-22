package main

import la "core:math/linalg"
import "core:encoding/cbor"
import "core:fmt"
import "core:os"
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
    //
    //rotation : quaternion128 = quaternion(real=0, imag=0, jmag=0, kmag=0)
    //shallow_angle: Level_Geometry
    //shallow_angle.shape = "basic_cube"
    //shallow_angle.collider = "basic_cube"
    //shallow_angle.transform = {{0, 0, 0},{10, 10, 10}, rotation}
    //shallow_angle.shaders = {.Trail}
    //shallow_angle.attributes = {.Shape, .Collider, .Active_Shaders, .Transform}
    //append(&aos_level_data, shallow_angle)

    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC)
    defer delete(bin)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_cbor :: proc(gs: ^Game_State, filename: string) {
    clear_soa(&gs.level_geometry)
    level_filename := str.concatenate({"levels/", filename, ".bin"})
    defer delete(level_filename)
    level_bin, read_err := os.read_entire_file(level_filename)
    defer delete(level_bin)
    decoded, decode_err := cbor.decode(string(level_bin))
    defer cbor.destroy(decoded)

    for entry in decoded.(^cbor.Array) {
        lg: Level_Geometry
        entry_bin, _ := cbor.encode(entry)
        defer delete(entry_bin)
        cbor.unmarshal(string(entry_bin), &lg)
        lg.attributes = trim_bit_set(lg.attributes)
        lg.shaders = trim_bit_set(lg.shaders)
        append(&gs.level_geometry, lg)
    }
}

