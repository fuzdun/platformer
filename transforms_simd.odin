package main
import "core:simd"

vec4_vec3_mask : #simd[16]u32 : {1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0} 

//apply_velocities :: proc(gs: ^Game_State, dt: f64) {
    //process_chunk :: proc(objects: #soa[]packed_data, vertices: []Vertex, mask: #simd[16]u32) {
        //trns_ptr := cast(^#simd[8]f32)objects.transform
        //v_pos_ptr := cast(^#simd[64]f32)objects.vertex_pos
        //v_norm_ptr := cast(^#simd[64]f32)objects.vertex_norm
        //v_ptr := cast(^#simd[64]f32)objects.transform
        //pos := simd.masked_load(pos_ptr, cast(#simd[16]f32)0, mask)     
        //vertex := simd.masked_load()
        //vel := simd.masked_load(vel_ptr, cast(#simd[16]f32)0, mask)     
        //pos = simd.select(attr_mask, pos + dt * vel, pos)
        //simd.masked_store(pos_ptr, pos, mask)
    //}
    //lgs := gs.level_geometry[:]
    //lgs: #soa[]packed_data  = {}
    vertices: []Vertex = {}
    //for i := 0; len(lgs) >= 4; i += 1 {
    //    process_chunk(lgs, vertices, vec4_vec3_mask)
        //lgs = lgs[4:]
    //}
//}

//pos_vel_mask :: proc(lgs: #soa[]Level_Geometry) -> (out: [dynamic]#simd[16]u32){
//    out = make([dynamic]#simd[16]u32)
//    for i in 0..< len(lgs) / 4 {
//        bits : #simd[16]u32
//        for j in 0..<4 {
//            attr := lgs[i * 4 + j].attributes
//            flag : u32 = .Position in attr && .Velocity in attr ? 1 : 0
//            bits = simd.replace(bits, j * 4, flag)
//            bits = simd.replace(bits, j * 4 + 1, flag)
//            bits = simd.replace(bits, j * 4 + 2, flag)
//            bits = simd.replace(bits, j * 4 + 3, flag)
//        }
//        append(&out, bits)
//    }
//    return
//}
//
