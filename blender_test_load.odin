package main
import str "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "core:encoding/endian"
import "core:bytes"
import gl "vendor:OpenGL"

load_blender_model :: proc(filename: string) -> (sd: ShapeData, load_ok: bool) {
    dir := "models/"
    ext := ".glb"
    data, ok := os.read_entire_file_from_filename(str.concatenate({dir, filename, ext}))
    if !ok {
        load_ok = false
        fmt.eprintln("failed to read file")
        return
    }
    defer delete(data)
    buf : bytes.Buffer
    bytes.buffer_init(&buf, data)
    defer bytes.buffer_destroy(&buf)
    bytes.buffer_seek(&buf, 12, .Current)
    json_len_bytes := bytes.buffer_next(&buf, 4)
    json_len, json_len_ok := endian.get_u32(json_len_bytes, .Little)
    if !json_len_ok {
        load_ok = false
        fmt.eprintln("failed to convert json_len to u32")
        return
    }
    bytes.buffer_seek(&buf, 4, .Current)
    json_data := bytes.buffer_next(&buf, int(json_len))
    parsed_json, parse_err := json.parse(json_data)
    if parse_err != .None {
        load_ok = false
        fmt.eprintln("failed to parse JSON")
        return
    }
    defer json.destroy_value(parsed_json)
    bin_len_bytes := bytes.buffer_next(&buf, 4)
    bin_len, bin_len_ok := endian.get_u32(json_len_bytes, .Little)
    if !bin_len_ok {
        load_ok = false
        fmt.eprintln("failed to convert bin_len to u32")
        return
    }
    bytes.buffer_seek(&buf, 4, .Current)
    bin_data := bytes.buffer_next(&buf, int(bin_len))
    json_obj := parsed_json.(json.Object)

    buffer_views := json_obj["bufferViews"].(json.Array)

    pos_offset := int(buffer_views[0].(json.Object)["byteOffset"].(json.Float))
    pos_len := int(buffer_views[0].(json.Object)["byteLength"].(json.Float))

    uv_offset := int(buffer_views[1].(json.Object)["byteOffset"].(json.Float))
    uv_len := int(buffer_views[1].(json.Object)["byteLength"].(json.Float))

    indices_offset := int(buffer_views[2].(json.Object)["byteOffset"].(json.Float))
    indices_len := int(buffer_views[2].(json.Object)["byteLength"].(json.Float))

    pos_start_ptr: rawptr = &bin_data[pos_offset]
    pos_bytes_len := pos_len / size_of([3]f32)
    pos_data := (transmute([^][3]f32)pos_start_ptr)[:pos_bytes_len]

    uv_start_ptr: rawptr = &bin_data[uv_offset]
    uv_bytes_len := uv_len / size_of([2]f32)
    uv_data := (transmute([^][2]f32)uv_start_ptr)[:uv_bytes_len]

    indices_start_ptr: rawptr = &bin_data[indices_offset]
    indices_bytes_len := indices_len / size_of(u16)
    indices_data := (transmute([^]u16)indices_start_ptr)[:indices_bytes_len]

    //fmt.println("===vertices===")
    //fmt.println(pos_data)
    //fmt.println("===uv===")
    //fmt.println(uv_data)
    //fmt.println("===indices===")
    //fmt.println(indices_data)

    
    sd = {}
    return
}
