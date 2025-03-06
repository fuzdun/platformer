package main
import str "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "core:encoding/endian"
import "core:bytes"
import gl "vendor:OpenGL"

load_blender_model :: proc(filename: string, gs: ^Game_State, ps: ^Physics_State) -> bool {

    // read binary data
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
    if parse_err != .None {
        fmt.eprintln("failed to parse JSON")
        return false
    }
    defer json.destroy_value(parsed_json)

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
    json_obj := parsed_json.(json.Object)
    buffer_views := json_obj["bufferViews"].(json.Array)

    sd := read_mesh_data_from_binary(buffer_views, bin_data, 0)
    gs.level_resources[filename] = sd
    if len(json_obj["scenes"].(json.Array)[0].(json.Object)["nodes"].(json.Array)) == 2 {
        coll := read_coll_data_from_binary(buffer_views, bin_data, 1)   
        ps.level_colliders[filename] = coll
    } else {
        coll := read_coll_data_from_binary(buffer_views, bin_data, 0)
        ps.level_colliders[filename] = coll
    }
    return true
}

read_mesh_data_from_binary :: proc(buffer_views: json.Array, binary_data: []u8, i: int) -> (sd: Shape_Data) {
    idx := i * 4

    pos_offset := int(buffer_views[idx].(json.Object)["byteOffset"].(json.Float))
    pos_len := int(buffer_views[idx].(json.Object)["byteLength"].(json.Float))

    norm_offset := int(buffer_views[idx + 1].(json.Object)["byteOffset"].(json.Float))
    norm_len := int(buffer_views[idx + 1].(json.Object)["byteLength"].(json.Float))

    uv_offset := int(buffer_views[idx + 2].(json.Object)["byteOffset"].(json.Float))
    uv_len := int(buffer_views[idx + 2].(json.Object)["byteLength"].(json.Float))

    indices_offset := int(buffer_views[idx + 3].(json.Object)["byteOffset"].(json.Float))
    indices_len := int(buffer_views[idx + 3].(json.Object)["byteLength"].(json.Float))

    pos_start_ptr: rawptr = &binary_data[pos_offset]
    pos_bytes_len := pos_len / size_of([3]f32)
    pos_data := (cast([^][3]f32)pos_start_ptr)[:pos_bytes_len]

    norm_start_ptr: rawptr = &binary_data[norm_offset]
    norm_bytes_len := norm_len / size_of([3]f32)
    norm_data := (cast([^][3]f32)norm_start_ptr)[:norm_bytes_len]

    uv_start_ptr: rawptr = &binary_data[uv_offset]
    uv_bytes_len := uv_len / size_of([2]f32)
    uv_data := (cast([^][2]f32)uv_start_ptr)[:uv_bytes_len]

    indices_start_ptr: rawptr = &binary_data[indices_offset]
    indices_bytes_len := indices_len / size_of(u16)
    indices_data := (cast([^]u16)indices_start_ptr)[:indices_bytes_len]

    sd.vertices = make([]Vertex, len(pos_data))
    sd.indices = make([]u32, len(indices_data))
    for pos, pi in pos_data {
        sd.vertices[pi] = {{pos[0], pos[1], pos[2]}, uv_data[pi], uv_data[pi], norm_data[pi]}
    }
    for ind, ind_i in indices_data {
        sd.indices[ind_i] = u32(ind)
    }
    //fmt.println(len(sd.vertices))
    //copy(sd.indices, indices_data)
    return
}

read_coll_data_from_binary :: proc(buffer_views: json.Array, binary_data: []u8, i: int) -> (coll: Collider_Data) {
    idx := i * 4

    pos_offset := int(buffer_views[idx].(json.Object)["byteOffset"].(json.Float))
    pos_len := int(buffer_views[idx].(json.Object)["byteLength"].(json.Float))

    indices_offset := int(buffer_views[idx + 3].(json.Object)["byteOffset"].(json.Float))
    indices_len := int(buffer_views[idx + 3].(json.Object)["byteLength"].(json.Float))

    pos_start_ptr: rawptr = &binary_data[pos_offset]
    pos_bytes_len := pos_len / size_of([3]f32)
    pos_data := (cast([^][3]f32)pos_start_ptr)[:pos_bytes_len]

    indices_start_ptr: rawptr = &binary_data[indices_offset]
    indices_bytes_len := indices_len / size_of(u16)
    indices_data := (cast([^]u16)indices_start_ptr)[:indices_bytes_len]

    coll.vertices = make([][3]f32, len(pos_data)) 
    coll.indices = make([]u16, len(indices_data))
    for pos, pi in pos_data {
        coll.vertices[pi] = {pos[0], pos[1], pos[2]}
    }
    copy(coll.indices, indices_data)
    return
}




