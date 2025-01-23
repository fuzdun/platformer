package main

import "core:fmt"
import "core:math"
import rnd "core:math/rand"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:os"

I_MAT :: glm.mat4(1.0)

RenderState :: struct {
    v_queue: [dynamic]Vertex,
    i_queue: [ProgramName][dynamic]u16,
    vbo: u32
}

init_render_buffers :: proc(rs: ^RenderState) {
    for program in ProgramName {
        rs.i_queue[program] = make([dynamic]u16) 
    }
    rs.v_queue = make([dynamic]Vertex)
}

clear_indices_queues :: proc(rs: ^RenderState) {
    for &arr in rs.i_queue {
        clear(&arr)
    }
}

free_render_buffers :: proc(rs: ^RenderState) {
    delete(rs.v_queue)
    for iq in rs.i_queue do delete(iq)
}

init_draw :: proc(rs: ^RenderState, ss: ^ShaderState) {
    init_shaders(ss)

    gl.GenBuffers(1, &rs.vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.vbo)

    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.Enable(gl.DEPTH_TEST)
}

add_object_to_render_buffers :: proc(gs: ^GameState, rs: ^RenderState, shape: Shape, transform: glm.mat4) {
    x := rnd.float32_range(-1, 1)
    y := rnd.float32_range(-1, 1)
    z := rnd.float32_range(-1, 1)
    vx := rnd.float32_range(-.01, .01)
    vy := rnd.float32_range(-.01, .01)
    vz := rnd.float32_range(-.01, .01)
    obj := add_entity(&gs.ecs)
    add_transform(&gs.ecs, obj, glm.mat4Translate({x, y, z}))
    if rnd.float32_range(0, 1) < 0.5 {
        add_velocity(&gs.ecs, obj, {vx, vy, vz})
    }
    add_shape(&gs.ecs, obj, shape)
}

get_vertices_from_renderables :: proc(gs: ^GameState, rs: ^RenderState, out: ^[dynamic]Vertex){
    using gs.ecs.comp_data
    query := [2]Component {.Shape, .Transform}
    ents := make([dynamic][2]uint); defer delete(ents)
    entities_with(&gs.ecs, query, &ents)
    for e in ents {
        s_i, t_i := e[0], e[1]
        indices_offset := u16(len(out))
        sd := SHAPE_DATA[shapes[s_i]]
        vertices := sd.vertices
        for indices_list in sd.indices_lists {
            shifted_indices := offset_indices(indices_list.indices[:], indices_offset)
            iq_idx := int(indices_list.shader)
            append(&rs.i_queue[indices_list.shader], ..shifted_indices[:])
        }
        transform_vertices(vertices, transforms[t_i], out)
    }
}

load_level :: proc(gs: ^GameState, rs: ^RenderState, ss: ShaderState) {
    for _ in 0..<1000 {
        shapes : []Shape = { .Cube, .InvertedPyramid }
        s := rnd.choice(shapes)
        x := rnd.float32_range(-20, 20)
        y := rnd.float32_range(-20, 20)
        z := rnd.float32_range(-20, 20)
        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)
        add_object_to_render_buffers(
            gs,
            rs,
            s,
            glm.mat4Translate({x, y, z}) *
            glm.mat4Rotate({1, 0, 0}, rx) *
            glm.mat4Rotate({0, 1, 0}, ry) *
            glm.mat4Rotate({0, 0, 1}, rz)
        )
    }
}


draw_triangles :: proc(gs: ^GameState, rs: ^RenderState, ss: ^ShaderState, time: f64) {
    clear_indices_queues(rs)
    transformed_vertices := make([dynamic]Vertex); defer delete(transformed_vertices)
    get_vertices_from_renderables(gs, rs, &transformed_vertices)
    for name, program in ss.active_programs {
        indices := rs.i_queue[name]
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, program.ebo_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
    }
    gl.BufferData(gl.ARRAY_BUFFER, size_of(transformed_vertices[0]) * len(transformed_vertices), raw_data(transformed_vertices), gl.STREAM_DRAW)

    rot := glm.mat4Rotate({1, 0, 0}, f32(crx)) * glm.mat4Rotate({ 0, 1, 0 }, f32(cry))
    proj := glm.mat4Perspective(45, WIDTH / HEIGHT, 0.01, 100)
    offset := glm.mat4Translate({f32(cx), f32(cy), f32(cz)})

    proj_mat := proj * rot * offset

    use_shader(ss, .Pattern)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .Pattern)

    use_shader(ss, .New)
    set_matrix_uniform(ss, "projection", &proj_mat)
    set_float_uniform(ss, "i_time", f32(time) / 1000)
    draw_shader(rs, ss, .New)

    use_shader(ss, .Outline)
    set_matrix_uniform(ss, "projection", &proj_mat)
    draw_shader(rs, ss, .Outline)
}
