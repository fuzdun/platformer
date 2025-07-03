package main

import str "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "core:encoding/endian"
import "core:bytes"
import gl "vendor:OpenGL"

import st "state"
import enm "enums"
import const "constants"
import typ "datatypes"

load_blender_model :: proc(shape: enm.SHAPE, lrs: ^st.Level_Resources, ps: ^st.Physics_State) -> bool {
    // read binary data
    filename := const.SHAPE_FILENAME[shape]
    binary_filename := str.concatenate({"models/", filename, ".glb"})
    defer delete(binary_filename)
    data, ok := os.read_entire_file_from_filename(binary_filename)
    defer delete(data)
    if !ok {
        fmt.eprintln("failed to read file")
        return false
    }
    // initialize buffer
    buf : bytes.Buffer
    bytes.buffer_init(&buf, data)
    defer bytes.buffer_destroy(&buf)
    // skip to bytes indicating json length
    bytes.buffer_seek(&buf, 12, .Current)
    // read 4 bytes and cast to u32
    json_len_bytes := bytes.buffer_next(&buf, 4)
    json_len, json_len_ok := endian.get_u32(json_len_bytes, .Little)
    if !json_len_ok {
        fmt.eprintln("failed to convert json_len to u32")
        return false
    }
    // skip to start of json
    bytes.buffer_seek(&buf, 4, .Current)
    // read up to json length and parse json
    json_data := bytes.buffer_next(&buf, int(json_len))
    parsed_json, parse_err := json.parse(json_data)
    defer json.destroy_value(parsed_json)
    if parse_err != .None {
        fmt.eprintln("failed to parse JSON")
        return false
    }
    // read 4 bytes indicating binary data length and cast to u32
    bin_len_bytes := bytes.buffer_next(&buf, 4)
    bin_len, bin_len_ok := endian.get_u32(bin_len_bytes, .Little)
    if !bin_len_ok {
        fmt.eprintln("failed to convert bin_len to u32")
        return false
    }
    // skip to start of binary data
    bytes.buffer_seek(&buf, 4, .Current)
    // read up to binary data length
    bin_data := bytes.buffer_next(&buf, int(bin_len))
    // get byte offsets/lengths of mesh attributes from json
    js: typ.model_json_struct
    json.unmarshal(json_data, &js)
    defer typ.free_model_json_struct(js) 

    collider_mesh_idx := len(js.scenes[0].nodes) == 2 ? 1 : 0
    lrs[shape] = read_mesh_data_from_binary(js, bin_data, 0, false).(typ.Shape_Data)
    ps.level_colliders[shape] = read_mesh_data_from_binary(js, bin_data, collider_mesh_idx, true).(typ.Collider_Data)
    return true
}

Model_Data :: union{typ.Shape_Data, typ.Collider_Data}

read_mesh_data_from_binary :: proc(model_data: typ.model_json_struct, binary_data: []u8, i: int, collider: bool) -> Model_Data {
    pos_idx := model_data.meshes[i].primitives[0].attributes["POSITION"]
    pos_offset := model_data.bufferViews[pos_idx].byteOffset
    pos_len := model_data.bufferViews[pos_idx].byteLength
    pos_start_ptr: rawptr = &binary_data[pos_offset]
    pos_bytes_len := pos_len / size_of([3]f32)
    pos_data := (cast([^][3]f32)pos_start_ptr)[:pos_bytes_len]

    indices_idx := model_data.meshes[i].primitives[0].indices
    indices_offset := model_data.bufferViews[indices_idx].byteOffset
    indices_len := model_data.bufferViews[indices_idx].byteLength
    indices_start_ptr: rawptr = &binary_data[indices_offset]
    indices_bytes_len := indices_len / size_of(u16)
    indices_data := (cast([^]u16)indices_start_ptr)[:indices_bytes_len]

    if !collider {
        norm_idx := model_data.meshes[i].primitives[0].attributes["NORMAL"]
        norm_offset := model_data.bufferViews[norm_idx].byteOffset
        norm_len := model_data.bufferViews[norm_idx].byteLength
        norm_start_ptr: rawptr = &binary_data[norm_offset]
        norm_bytes_len := norm_len / size_of([3]f32)
        norm_data := (cast([^][3]f32)norm_start_ptr)[:norm_bytes_len]

        uv_idx := model_data.meshes[i].primitives[0].attributes["TEXCOORD_0"]
        uv_offset := model_data.bufferViews[uv_idx].byteOffset
        uv_len := model_data.bufferViews[uv_idx].byteLength
        uv_start_ptr: rawptr = &binary_data[uv_offset]
        uv_bytes_len := uv_len / size_of([2]f32)
        uv_data := (cast([^][2]f32)uv_start_ptr)[:uv_bytes_len]

        sd: typ.Shape_Data
        sd.vertices = make([]typ.Vertex, len(pos_data))
        sd.indices = make([]u32, len(indices_data))
        for pos, pi in pos_data {
            sd.vertices[pi] = {{pos[0], pos[1], pos[2]}, uv_data[pi], uv_data[pi], norm_data[pi]}
        }
        for ind, ind_i in indices_data {
            sd.indices[ind_i] = u32(ind)
        }
        return sd
    }
    coll: typ.Collider_Data
    coll.vertices = make([][3]f32, len(pos_data)) 
    coll.indices = make([]u16, len(indices_data))
    for pos, pi in pos_data {
        coll.vertices[pi] = {pos[0], pos[1], pos[2]}
    }
    copy(coll.indices, indices_data)
    return coll
}

