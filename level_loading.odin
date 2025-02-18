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

encode_test_level_cbor :: proc() {
    test_level_data := make(#soa[dynamic]Level_Geometry)
    defer delete(test_level_data)

    box : Level_Geometry
    rx, ry, rz : f32 = 0, 0, -.35 
    rot := la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
    trns: Transform = make_transform({0, -2, 4}, {10, 10, 10}, rot)
    box.transform = trns
    box.shaders  = {.Trail, .RedOutline}
    box.shape = "cube"
    box.collider = "cube_collider"
    box.attributes = {.Transform, .Shape, .Collider, .Active_Shaders}
    append(&test_level_data, box)

    aos_level_data := make([dynamic]Level_Geometry)
    defer delete(aos_level_data)
    for lg in test_level_data {
        append(&aos_level_data, lg)
    }

    bin, err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC)
    os.write_entire_file("levels/test_level.bin", bin)
}

load_level_cbor :: proc(gs: ^Game_State, filename: string) {
    clear_soa(&gs.level_geometry)
    level_bin, read_err := os.read_entire_file(str.concatenate({"levels/", filename, ".bin"}))
    decoded, decode_err := cbor.decode(string(level_bin))

    for entry in decoded.(^cbor.Array) {
        lg: Level_Geometry
        entry_bin, _ := cbor.encode(entry)
        cbor.unmarshal(string(entry_bin), &lg)
        lg.attributes = trim_bit_set(lg.attributes)
        lg.shaders = trim_bit_set(lg.shaders)
        append(&gs.level_geometry, lg)
    }
}

