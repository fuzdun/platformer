package main
import str "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "core:encoding/endian"
import "core:bytes"
import gl "vendor:OpenGL"

load_blender_model :: proc(filename: string, gs: ^Game_State) -> bool {

    // read binary data
    dir := "models/"
    ext := ".glb"
    data, ok := os.read_entire_file_from_filename(str.concatenate({dir, filename, ext}))
    if !ok {
        fmt.eprintln("failed to read file")
        return false
    }
    defer delete(data)

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
    bin_len, bin_len_ok := endian.get_u32(json_len_bytes, .Little)
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

    pos_offset := int(buffer_views[0].(json.Object)["byteOffset"].(json.Float))
    pos_len := int(buffer_views[0].(json.Object)["byteLength"].(json.Float))

    norm_offset := int(buffer_views[1].(json.Object)["byteOffset"].(json.Float))
    norm_len := int(buffer_views[1].(json.Object)["byteLength"].(json.Float))

    uv_offset := int(buffer_views[2].(json.Object)["byteOffset"].(json.Float))
    uv_len := int(buffer_views[2].(json.Object)["byteLength"].(json.Float))

    indices_offset := int(buffer_views[3].(json.Object)["byteOffset"].(json.Float))
    indices_len := int(buffer_views[3].(json.Object)["byteLength"].(json.Float))

    // get binary chunks corresponding to attributes and recast to arrays of proper datatype
    pos_start_ptr: rawptr = &bin_data[pos_offset]
    pos_bytes_len := pos_len / size_of([3]f32)
    pos_data := (cast([^][3]f32)pos_start_ptr)[:pos_bytes_len]

    norm_start_ptr: rawptr = &bin_data[norm_offset]
    norm_bytes_len := norm_len / size_of([3]f32)
    norm_data := (cast([^][3]f32)norm_start_ptr)[:norm_bytes_len]

    uv_start_ptr: rawptr = &bin_data[uv_offset]
    uv_bytes_len := uv_len / size_of([2]f32)
    uv_data := (cast([^][2]f32)uv_start_ptr)[:uv_bytes_len]

    indices_start_ptr: rawptr = &bin_data[indices_offset]
    indices_bytes_len := indices_len / size_of(u16)
    indices_data := (cast([^]u16)indices_start_ptr)[:indices_bytes_len]

    //fmt.println("===vertices===")
    //fmt.println(pos_data)
    //fmt.println("===normals===")
    //fmt.println(norm_data)
    //fmt.println("===uv===")
    //fmt.println(uv_data)
    //fmt.println("===indices===")
    //fmt.println(indices_data)
         
    sd: Shape_Data
    sd.vertices = make([]Vertex, len(pos_data))
    sd.indices_lists[.Render] = make([]u16, len(indices_data))
    sd.indices_lists[.Collision] = make([]u16, len(indices_data))
    for pos, i in pos_data {
        sd.vertices[i] = {{pos[0], pos[1], pos[2], 1.0}, uv_data[i]}
        copy(sd.indices_lists[.Render], indices_data)
        copy(sd.indices_lists[.Collision], indices_data)
    }
    gs.level_resources[filename] = sd
    return true
}
