package main

import la "core:math/linalg"
import "core:encoding/cbor"
// import "core:fmt"
import "core:os"
import "core:math"
import "base:runtime"
import rnd "core:math/rand"
// import str "core:strings"
import hm "core:container/handle_map"

trim_bit_set :: proc(bs: bit_set[$T; u64]) -> (out: bit_set[T; u64]){
    for val in T {
        if val in bs {
            out += {val}
        }
    }
    return
}

encode_test_level_cbor :: proc(lgs: ^Level_Geometry_State, dest: string) {
    level_data := make([dynamic]Level_Geometry, context.temp_allocator)
    lg_it := hm.iterator_make(lgs)
    for lg, handle in hm.iterate(&lg_it) {
        // lg.attributes = {.Collider, .Crackable}
        append(&level_data, lg^)
    }
    bin, marshal_err := cbor.marshal(level_data, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
    write_err := os.write_entire_file(dest, bin)
}

generate_new_chunk :: proc(lgs: Level_Geometry_State) {
    aos_level_data := make([dynamic]Level_Geometry, context.temp_allocator)
    lg: Level_Geometry
    append(&aos_level_data, lg)
    bin, marshal_err := cbor.marshal(aos_level_data, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
    write_err := os.write_entire_file("chunks/new_chunk.bin", bin)
}

generate_level :: proc(arena: runtime.Allocator) -> []Level_Geometry {
    // level_geometry := make([]Level_Geometry, 300, arena)
    // spawn_offset := [3]f32{0, 0, 0}
    // entry_idx := 0
    // for _ in 0..<30 {
    //     flip := rnd.choice([]int{0, 1}) == 1
    //      chunk_num := rnd.choice([]string{"0", "1", "2", "3", "4", "7" })
    //     //chunk_num := rnd.choice([]string{"0", "1", "2", "3", "4", "5", "6", "7"})
    //     level_filename := str.concatenate({"chunks/chunk_", chunk_num, ".bin"}, context.temp_allocator)
    //     level_bin, read_err := os.read_entire_file(level_filename, context.temp_allocator)
    //     decoded, decode_err := cbor.decode(string(level_bin), nil, context.temp_allocator)
    //     decoded_arr := decoded.(^cbor.Array)
    //     for entry in decoded_arr {
    //         lg: Level_Geometry
    //
    //         // USE SEPARATE LG TYPE FOR UNMARSHALING LOADED DATA, SINCE WE DON'T NEED TO KEEP IT ALL AROUND
    //         // ALSO CREATE A SUBTYPES OF RENDER_DATA FOR DIFFERENT PIPELINES, BUT DON'T TRY TO OVERGENERALIZE
    //         // / OOP-IFY THE DRAW CODE. JUST CREATE INIT FUNCTIONS FOR SHADER PIPELINES
    //
    //         entry_bin, _ := cbor.encode(entry, cbor.ENCODE_SMALL, context.temp_allocator)
    //         cbor.unmarshal(string(entry_bin), &lg)
    //         lg.attributes = trim_bit_set(lg.attributes)
    //         render_data_handle, ok := hm.add(lgrs, Level_Geometry_Render_Data {
    //             render_group = lg_render_group(lg),
    //             transparency = 1
    //         })
    //         lg.render_data_handle = render_data_handle
    //         lg.transform.position += spawn_offset
    //         level_geometry[entry_idx] = lg
    //         entry_idx += 1
    //     }
    //     spawn_offset.z -= CHUNK_DEPTH
    // }
    // return level_geometry
    level_geometry := make([]Level_Geometry, 300, arena)
    spawn_offset := [3]f32{0, 0, 0}
    x_offset: f32 = 0
    no_skip_next := false
    i := 0
    for idx in 0..<300 {
        skip_next := false
        if no_skip_next {
            no_skip_next = false
        } else {
            if rnd.float32() < 0.5 {
                skip_next = true
                no_skip_next = true
            }
        }
        x_offset += rnd.float32() * 90.0 - 45.0
        lg: Level_Geometry
        lg.attributes = {.Collider} 
        lg.jump_block = skip_next ? 0.0 : 0.0
        lg.transform.position = spawn_offset + [3]f32{x_offset, -40, f32(i) * -BEAT_SPACE} 
        lg.transform.rotation = la.quaternion_from_euler_angle_x(f32(0.2))
        lg.transform.scale = 25
        level_geometry[idx] = lg
        // i += skip_next ? 2 : 1
        i += 1
    }
    return level_geometry
}

load_level_geometry :: proc(filename: string, arena: runtime.Allocator) -> []Level_Geometry {
    // level_prefix := loading_chunk ? "chunks/chunk_" : "levels/"
    // level_filename := str.concatenate({level_prefix, filename, ".bin"}, context.temp_allocator)
    level_bin, read_err := os.read_entire_file(filename, context.temp_allocator)
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
            lg.transform = {{x * 75, y * 1 - 80, y * -25 + 200},{30, 30, 30}, rot}
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
            loaded_level_geometry[idx] = lg
        }
    }
    return loaded_level_geometry
}

