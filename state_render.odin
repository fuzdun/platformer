package main

import "base:runtime"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import hm "core:container/handle_map"

OUTER_TESSELLATION_AMT :: 3.0
INNER_TESSELLATION_AMT :: 3.0

I_MAT :: glm.mat4(1.0)

SHAPE :: enum {
    CUBE,
    CYLINDER,
    ICO,
    DASH_BARRIER,
    SLIDE_ZONE,
    ICE_CREAM,
    BOUNCY,
    CHAIR,
    FRANK,
    SPIN_TRAIL,
}

Handle :: distinct hm.Handle32

Level_Geometry_Render_Type :: enum {
    Standard,
    Dither_Test,
    Dash_Barrier,
    Wireframe,
    Slide_Zone,
    Bouncy
}

Level_Geometry_Render_Type_Name :: [Level_Geometry_Render_Type]string {
    .Standard = "Standard",
    .Dither_Test = "Dither_Test",
    .Dash_Barrier = "Dash_Barrier",
    .Wireframe = "Wireframe",
    .Slide_Zone = "Slide_Zone",
    .Bouncy = "Bouncy",
}

NUM_RENDER_GROUPS :: len(SHAPE) * len(Level_Geometry_Render_Type) 


Render_State :: struct {
    player_trail_sample: [3]glm.vec3,
    prev_player_trail_sample: [3]glm.vec3,
    player_trail: RingBuffer(TRAIL_SIZE, [3]f32),

    player_vertex_displacment: [3]f32,
    tgt_player_vertex_displacement: [3]f32,

    player_spike_compression: f32,

    crunch_pt: [3]f32,
    crunch_time: f32,
    screen_splashes: [dynamic][4]f32,
    screen_ripple_pt: [2]f32,
}

Level_Geometry_Render_Data :: struct {
    handle: Handle,
    transform: Transform,
    render_group: int,
    transparency: f32,
    shatter_data: Shatter_Ubo,
}

Level_Geometry_Render_Data_State :: hm.Dynamic_Handle_Map(Level_Geometry_Render_Data, Handle)

Quad_Vertex :: struct {
    position: glm.vec3,
    uv: glm.vec2
}

Quad_Vertex4 :: struct {
    position: glm.vec4,
    uv: glm.vec2
}

Line_Vertex :: struct {
    position: glm.vec3,
    t: f32,
    color: glm.vec3
}

Break_Data :: struct {
    time: f32,
    pos: [3]f32,
    dir: [3]f32
}

Common_Ubo :: struct {
    projection: glm.mat4,
    time: f32
}

Dash_Ubo :: struct {
    dash_time: f32,
    dash_total: f32,
    constrain_dir: glm.vec3,
}

Tess_Ubo :: struct #align(16){
    inner_amt: f32,
    outer_amt: f32
}

Shatter_Ubo :: struct #packed {
    smash_time: f32,
    smash_pos: [3]f32, 
    crack_time: f32,
    smash_dir: [3]f32,
}

Z_Width_Ubo :: struct #align(16) {
    z_width: f32
}

Transparency_Ubo :: struct #align(16) {
    transparency: f32
}

Render_Groups :: [Level_Geometry_Render_Type][dynamic]gl.DrawElementsIndirectCommand 

init_render_state :: proc(rs: ^Render_State, perm_alloc: runtime.Allocator) {
    rs.player_spike_compression = 1.0
    rs.crunch_time = -10000.0;
    rs.screen_splashes = make([dynamic][4]f32, perm_alloc)
    ring_buffer_init(&rs.player_trail, [3]f32{0, 0, 0}, perm_alloc)
}

free_render_state :: proc(rs: Render_State) {
    delete(rs.screen_splashes)
    ring_buffer_free(rs.player_trail)
}

lg_render_group :: proc(lg: Level_Geometry) -> int {
    return int(lg.render_type) * len(SHAPE) + int(lg.shape)
}

interpolated_trail :: proc(rs: Render_State, t: f32) -> [3]glm.vec3 {
    return math.lerp(rs.prev_player_trail_sample, rs.player_trail_sample, t)
}

editor_sort_lgs :: proc(lgs: ^Level_Geometry_State, current_selection: int = 0) -> (new_selection: int = 0) {
    sorted_lgs := make([]Level_Geometry, len(lgs))
    defer delete(sorted_lgs)
    group_counts: [NUM_RENDER_GROUPS]int
    for lg, idx in lgs {
        group_counts[lg_render_group(lg)] += 1
    }
    counts_to_offsets(group_counts[:])
    for lg, idx in lgs {
        render_group := lg_render_group(lg) 
        insert_idx := group_counts[render_group]
        group_counts[render_group] += 1
        sorted_lgs[insert_idx] = lg
        if idx == current_selection {
            new_selection = insert_idx
        }
    }
    clear(lgs)
    for lg in sorted_lgs {
        append(lgs, lg)
    }
    return
}

sort_lgs :: proc(lgs: Level_Geometry_State, alloc: runtime.Allocator) -> Level_Geometry_State {
    sorted_lgs := make(Level_Geometry_State, len(lgs), alloc)
    group_counts: [NUM_RENDER_GROUPS]int
    for lg, idx in lgs {
        group_counts[lg_render_group(lg)] += 1
    }
    counts_to_offsets(group_counts[:])
    for lg, idx in lgs {
        render_group := lg_render_group(lg) 
        insert_idx := group_counts[render_group]
        group_counts[render_group] += 1
        sorted_lgs[insert_idx] = lg
        sorted_lgs[idx] = lg
    }
    return sorted_lgs
}

offsets_to_render_commands :: proc(offsets: []int, lg_count: int, rs: Render_State, sr: Shape_Resources) -> Render_Groups {
    render_groups: Render_Groups
    for &rg in render_groups {
        rg = make([dynamic]gl.DrawElementsIndirectCommand, context.temp_allocator)
    } 
    for g_off, idx in offsets {
        next_off := idx == len(offsets) - 1 ? lg_count : offsets[idx + 1]
        count := u32(next_off - g_off)
        if count == 0 do continue
        shape := SHAPE(idx % len(SHAPE))
        render_type := Level_Geometry_Render_Type(math.floor(f32(idx) / f32(len(SHAPE))))
        sd := sr.level_geometry[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            count,
            sr.index_offsets[shape],
            sr.vertex_offsets[shape],
            u32(g_off)
        }
        append(&render_groups[render_type], command)
    }
    return render_groups
}

render_text :: proc(shst: ^Shader_State, rs: ^Render_State, bs: Buffer_State, text: string, pos: [3]f32, cam_up: [3]f32, cam_right: [3]f32, scale: f32) {
    x: f32 = 0
    trans_mat: = la.matrix4_translate(pos)
    set_matrix_uniform(shst, "transform", &trans_mat)
    for c in str.trim_null(text) {
        char_tex := bs.char_tex_map[c]
        x_off := x + f32(char_tex.bearing.x) * scale
        y_off := -f32(char_tex.size.y - char_tex.bearing.y) * scale
        w := f32(char_tex.size.x) * scale
        h := f32(char_tex.size.y) * scale

        vertices := [4]Quad_Vertex4 {
            {{x_off,     y_off,     0, 1}, {0, 1}},
            {{x_off + w, y_off,     0, 1}, {1, 1}},
            {{x_off,     y_off + h, 0, 1}, {0, 0}},
            {{x_off + w, y_off + h, 0, 1}, {1, 0}},
        }
        for &v in vertices {
            v.position.xyz = cam_right * v.position.x + cam_up * v.position.y
        }
        gl.BindTexture(gl.TEXTURE_2D, char_tex.id)
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.text_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    
        x += f32(char_tex.next >> 6) * scale
    } 
}

render_screen_text :: proc(shst: ^Shader_State, bs: Buffer_State, text: string, pos: [3]f32, proj: glm.mat4, scale: f32) {
    screen_pos := proj * [4]f32 {pos.x, pos.y, pos.z, 1}
    screen_pos /= screen_pos.w
    x := screen_pos.x
    y := screen_pos.y + .05
    for c in str.trim_null(text) {
        char_tex := bs.char_tex_map[c]
        x_off := x + (f32(char_tex.bearing.x) * scale) / WIDTH
        y_off := y + (-f32(char_tex.size.y - char_tex.bearing.y) * scale) / HEIGHT
        w := (f32(char_tex.size.x) * scale) / WIDTH
        h := (f32(char_tex.size.y) * scale) / HEIGHT

        vertices := [4]Quad_Vertex4 {
            {{x_off,     y_off,     0, 1}, {0, 1}},
            {{x_off + w, y_off,     0, 1}, {1, 1}},
            {{x_off,     y_off + h, 0, 1}, {0, 0}},
            {{x_off + w, y_off + h, 0, 1}, {1, 0}},
        }
        gl.BindTexture(gl.TEXTURE_2D, char_tex.id)
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.text_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        x += (f32(char_tex.next >> 6) * scale) / WIDTH
    } 
}

draw_indirect_render_queue :: proc(bs: Buffer_State, queue: []gl.DrawElementsIndirectCommand, mode: u32) {
    if len(queue) > 0 {
        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, bs.indirect_buffer)
        gl.BufferData(gl.DRAW_INDIRECT_BUFFER, size_of(queue[0]) * len(queue), raw_data(queue), gl.DYNAMIC_DRAW)
        gl.MultiDrawElementsIndirect(mode, gl.UNSIGNED_INT, nil, i32(len(queue)), 0)
    }
}

trans_to_mat4 :: proc(trns: Transform) -> glm.mat4 {
    off := glm.mat4Translate(trns.position)
    rot := glm.mat4FromQuat(trns.rotation)
    scale := glm.mat4Scale(trns.scale)
    return off * rot * scale
}

easeout_cubic :: proc(n: f32) -> f32 {
    return 1.0 - math.pow(1.0 - n, 3);
}

easeout :: proc(n: f32) -> f32 {
    return math.sin(n * math.PI / 2.0);
}

counts_to_offsets :: proc(arr: []int) {
    for &val, idx in arr[1:] {
       val += arr[idx] 
    }
    #reverse for &val, idx in arr {
        val = idx == 0 ? 0 : arr[idx - 1]
    }
}


