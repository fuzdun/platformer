package main

import "core:fmt"
import "core:math"
import "core:slice"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"
import tm "core:time"

// PLAYER_PARTICLE_STACK_COUNT :: 6
// PLAYER_PARTICLE_SECTOR_COUNT :: 8 
PLAYER_PARTICLE_STACK_COUNT :: 4
PLAYER_PARTICLE_SECTOR_COUNT :: 7

PLAYER_PARTICLE_COUNT :: PLAYER_PARTICLE_STACK_COUNT * PLAYER_PARTICLE_SECTOR_COUNT + 2
I_MAT :: glm.mat4(1.0)

SHAPES :: enum{
    CUBE,
    WEIRD,
}

SHAPE_NAMES := [SHAPES]string {
    .CUBE = "basic_cube",
    .WEIRD = "weird"
}

Quad_Vertex :: struct {
    position: glm.vec3,
    uv: glm.vec2
}

BACKGROUND_VERTICES :: [4]Quad_Vertex {
    {{-1, -1, -1}, {0, 0}},
    {{1, -1, -1}, {1, 0}},
    {{-1, 1, -1}, {0, 1}},
    {{1, 1, -1}, {1, 1}},
}

PARTICLE_VERTICES :: [4]Quad_Vertex {
    {{-0.9, -0.9, 0.0}, {0, 0}},
    {{0.9, -0.9, 0.0}, {1, 0}},
    {{-0.9, 0.9, 0.0}, {0, 1}},
    {{0.9, 0.9, 0.0}, {1, 1}},
}

Vertex_Offsets :: [len(SHAPES)]u32
Index_Offsets :: [len(SHAPES)]u32

Render_State :: struct {
    standard_vao: u32,
    particle_vao: u32,
    background_vao: u32,
    lines_vao: u32,

    standard_ebo: u32,
    background_ebo: u32,

    standard_vbo: u32,
    particle_vbo: u32,
    particle_pos_vbo: u32,
    background_vbo: u32,
    editor_lines_vbo: u32,

    indirect_buffer: u32,

    transforms_ssbo: u32,
    z_widths_ssbo: u32,

    static_transforms: [dynamic]glm.mat4,
    player_particle_poss: [dynamic]glm.vec3,
    z_widths: [dynamic]f32,
    shader_render_queues: Shader_Render_Queues,
    player_particles: [PLAYER_PARTICLE_COUNT][4]f32,
    vertex_offsets: Vertex_Offsets,
    index_offsets: Index_Offsets,
    player_vertex_offset: u32,
    player_index_offset: u32,
    render_group_offsets: [len(ProgramName) * len(SHAPES)]u32
}

Renderable :: struct{
    transform: glm.mat4,
    z_width: f32
}

Shader_Render_Queues :: [ProgramName][dynamic]gl.DrawElementsIndirectCommand

load_geometry_data :: proc(gs: ^Game_State, ps: ^Physics_State) {
    for shape in SHAPES {
        if ok := load_blender_model(shape, gs, ps); ok {
            fmt.println("loaded", shape) 
        }
    }
}

init_render_buffers :: proc(gs: ^Game_State, rs: ^Render_State) {
    for shader in ProgramName {
        rs.shader_render_queues[shader] = make([dynamic]gl.DrawElementsIndirectCommand)
    }
    rs.static_transforms = make([dynamic]glm.mat4)
    rs.z_widths = make([dynamic]f32)
    rs.player_particle_poss = make([dynamic]glm.vec3)
    add_player_sphere_data(gs)
}

clear_render_state :: proc(rs: ^Render_State) {
    clear(&rs.static_transforms)
    clear(&rs.z_widths)
    for &off in rs.render_group_offsets {
        off = 0
    }
}

clear_render_queues :: proc(rs: ^Render_State) {
    for shader in ProgramName {
        clear(&rs.shader_render_queues[shader])
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    for shader in ProgramName {
        delete(rs.shader_render_queues[shader])
    }
    delete(rs.static_transforms)
    delete(rs.z_widths)
}

init_draw :: proc(rs: ^Render_State, ss: ^ShaderState) -> bool {
    if !init_shaders(ss) {
        fmt.eprintln("shader init failed")
        return false
    }

    gl.GenBuffers(1, &rs.standard_vbo)
    gl.GenBuffers(1, &rs.standard_ebo)
    gl.GenBuffers(1, &rs.indirect_buffer)
    gl.GenBuffers(1, &rs.transforms_ssbo)
    gl.GenBuffers(1, &rs.z_widths_ssbo)
    gl.GenBuffers(1, &rs.particle_vbo)
    gl.GenBuffers(1, &rs.particle_pos_vbo)
    gl.GenBuffers(1, &rs.background_vbo)
    gl.GenBuffers(1, &rs.editor_lines_vbo)
    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenVertexArrays(1, &rs.particle_vao)
    gl.GenVertexArrays(1, &rs.background_vao)
    gl.GenVertexArrays(1, &rs.lines_vao)

    gl.BindVertexArray(rs.standard_vao)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, b_uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

    gl.BindVertexArray(rs.particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, position))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, uv))
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, false, 0, 0)
    gl.VertexAttribDivisor(0, 0)
    gl.VertexAttribDivisor(1, 0)
    gl.VertexAttribDivisor(2, 1)

    bv := BACKGROUND_VERTICES
    gl.BindVertexArray(rs.background_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.background_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(bv[0]) * len(bv), &bv[0], gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, uv))

    gl.BindVertexArray(rs.lines_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of([3]f32), 0)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    gl.TexParameteri(gl.TEXTURE_2D, gl.GENERATE_MIPMAP, 0)
    return true
}

init_level_render_data :: proc(gs: ^Game_State, rs: ^Render_State) {
    vertices := make([dynamic]Vertex); defer delete(vertices)
    indices := make([dynamic]u32); defer delete(indices)
    for shape in SHAPES {
        rs.vertex_offsets[int(shape)] = u32(len(vertices))
        rs.index_offsets[int(shape)] = u32(len(indices))
        sd := gs.level_resources[shape]
        append(&indices, ..sd.indices)
        append(&vertices, ..sd.vertices)
    }
    rs.player_vertex_offset = u32(len(vertices))
    rs.player_index_offset = u32(len(indices))
    append(&indices, ..gs.player_geometry.indices)
    append(&vertices, ..gs.player_geometry.vertices)

    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW) 
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)
}

update_vertices :: proc(gs: ^Game_State, rs: ^Render_State) {
    if len(gs.dirty_entities) > 0 {
        for lg_idx in gs.dirty_entities {
            lg := gs.level_geometry[lg_idx]
            trans_mat := trans_to_mat4(lg.transform)
            max_z := min(f32)
            min_z := max(f32)
            for v in gs.level_resources[lg.shape].vertices {
                new_pos := trans_mat * [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}
                max_z = max(new_pos.z, max_z)
                min_z = min(new_pos.z, min_z)
            }

            for offset, shader in lg.ssbo_indexes {
                if offset != -1 {
                    ssbo_idx := get_ssbo_idx(lg, shader, rs^)
                    if ssbo_idx > len(rs.static_transforms) - 1 {
                        append(&rs.static_transforms, trans_mat) 
                        append(&rs.z_widths, max_z - min_z)
                    } else {
                        rs.static_transforms[ssbo_idx] = trans_mat
                        rs.z_widths[ssbo_idx] = max_z - min_z
                    }
                }
            }
        }
    }
    clear(&gs.dirty_entities)

}

update_player_particles :: proc(rs: ^Render_State, ps: Player_State, time: f32) {
    vertical_count := PLAYER_PARTICLE_STACK_COUNT
    horizontal_count := PLAYER_PARTICLE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u32
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count + 1)
    horizontal_step := (2 * PI) / f32(horizontal_count)
    // sphere_rotate := la.matrix3_from_euler_angles(time / 4000, time / 4000, 0, .XYZ)
    sphere_rotate := la.matrix3_from_euler_angles(time / 300, time / 300, 0, .XYZ)
    for i in 0..<vertical_count {
        vertical_angle = PI / 2.0 - f32(i + 1) * vertical_step
        xz := SPHERE_RADIUS * math.cos(vertical_angle)
        y = SPHERE_RADIUS * math.sin(vertical_angle)
        for j in 0..<horizontal_count {
            id := i * horizontal_count + j
            horizontal_angle = f32(j) * horizontal_step
            x = xz * math.cos(horizontal_angle)
            z = xz * math.sin(horizontal_angle)
            // pos: [4]f32 = {x, y, z, f32(id)}
            pos: [4]f32 = {x, y, z, f32(id)}
            pos.xyz = sphere_rotate * pos.xyz * 2.0

            displacement_fact := la.dot(ps.particle_displacement, pos.xyz)
            if displacement_fact > 0 {
                displacement_fact *= 0.2
            }
            pos.xyz += la.clamp_length(ps.particle_displacement * displacement_fact * 0.0005, 12.0)

            rs.player_particles[i * horizontal_count + j] = pos
        }
    }
    end_idx := vertical_count * horizontal_count
    top_pt: [4]f32 = {0, SPHERE_RADIUS * 2.0, 0, f32(end_idx)}
    bot_pt: [4]f32 = {0, -SPHERE_RADIUS * 2.0, 0, f32(end_idx + 1)}
    top_pt.xyz = sphere_rotate * top_pt.xyz
    bot_pt.xyz = sphere_rotate * bot_pt.xyz
    rs.player_particles[end_idx] = top_pt
    rs.player_particles[end_idx + 1] = bot_pt
    
    // z_sort := proc(a: [4]f32, b: [4]f32) -> bool { return a.z < b.z }
    z_sort := proc(a: [4]f32, b: [4]f32) -> bool { return a.z < b.z }
    slice.sort_by(rs.player_particles[:], z_sort)
}

render :: proc(gs: ^Game_State, rs: ^Render_State, shst: ^ShaderState, ps: ^Physics_State, time: f64, interp_t: f64) {
    clear_render_queues(rs)

    // add level geometry to command queues
    for g_off, idx in rs.render_group_offsets {
        next_off := idx == len(rs.render_group_offsets) - 1 ? u32(len(gs.level_geometry)) : rs.render_group_offsets[idx + 1]
        count := next_off - g_off
        if count == 0 do continue
        shader := ProgramName(idx / len(SHAPES))
        shape := SHAPES(idx % len(SHAPES))
        sd := gs.level_resources[shape] 
        command: gl.DrawElementsIndirectCommand = {
            u32(len(sd.indices)),
            next_off - g_off,
            rs.index_offsets[shape],
            rs.vertex_offsets[shape],
            g_off
        }
        append(&rs.shader_render_queues[shader], command)
    }

    // add player to command queue
    player_mat := interpolated_player_matrix(&gs.player_state, f32(interp_t))
    player_rq := rs.shader_render_queues[.Player]
    //append(&player_rq.transforms, player_mat)
    append(&player_rq, gl.DrawElementsIndirectCommand{
        u32(len(gs.player_geometry.indices)),
        1,
        rs.player_index_offset,
        rs.player_vertex_offset,
        0
    })
    rs.shader_render_queues[.Player] = player_rq

    // execute draw queues
    proj_mat: glm.mat4
    if EDIT {
        proj_mat = construct_camera_matrix(&gs.camera_state)
    } else {
        proj_mat = interpolated_camera_matrix(&gs.camera_state, f32(interp_t))
    }

    if !EDIT {
        gl.Disable(gl.DEPTH_TEST)
        gl.Disable(gl.CULL_FACE)
        bqv := BACKGROUND_VERTICES
        gl.BindVertexArray(rs.background_vao)
        use_shader(shst, rs, .Background)
        set_float_uniform(shst, "i_time", f32(time) / 1000)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.background_vbo)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
        gl.Enable(gl.DEPTH_TEST)
        gl.Enable(gl.CULL_FACE)
    }

    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.static_transforms[0]) * len(rs.static_transforms), raw_data(rs.static_transforms), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(rs.z_widths[0]) * len(rs.z_widths), raw_data(rs.z_widths), gl.DYNAMIC_DRAW)
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)

    if !EDIT {
        use_shader(shst, rs, .Player)
        p_color: [3]f32 = gs.player_state.dashing ? {0.0, 1.0, 0} : {0.8, 0.4, 0.0}
        set_matrix_uniform(shst, "projection", &proj_mat)
        set_matrix_uniform(shst, "transform", &player_mat)
        set_float_uniform(shst, "i_time", f32(time) / 1000)
        set_vec3_uniform(shst, "p_color", 1, &p_color)
        draw_shader_render_queue(rs, shst, gl.TRIANGLES)
    }

    use_shader(shst, rs, .Simple)
    set_matrix_uniform(shst, "projection", &proj_mat)
    draw_shader_render_queue(rs, shst, gl.TRIANGLES)

    //fmt.println("===")
    if EDIT {
        use_shader(shst, rs, .Trail)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_shader_render_queue(rs, shst, gl.TRIANGLES)
    } else {
        use_shader(shst, rs, .Trail)
        crunch_pt : glm.vec3 = gs.player_state.crunch_pt
        player_pos := gs.player_state.position
        player_trail := interpolated_trail(&gs.player_state, f32(interp_t))
        set_vec3_uniform(shst, "player_trail", 3, &player_trail[0])
        set_vec3_uniform(shst, "player_pos", 1, &player_pos)
        set_vec3_uniform(shst, "crunch_pt", 1, &crunch_pt)
        set_float_uniform(shst, "crunch_time", f32(gs.player_state.crunch_time) / 1000)
        set_float_uniform(shst, "time", f32(time) / 1000)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_shader_render_queue(rs, shst, gl.PATCHES)
    }

    // PARTICLE DRAW TEST ZONE=========
    if !EDIT {
        use_shader(shst, rs, .Player_Particle)
        gl.BindVertexArray(rs.particle_vao)
        pv := PARTICLE_VERTICES
        
        camera_right_worldspace: [3]f32 = {proj_mat[0][0], proj_mat[1][0], proj_mat[2][0]}
        camera_right_worldspace = la.normalize(camera_right_worldspace)
        camera_up_worldspace: [3]f32 = {proj_mat[0][1], proj_mat[1][1], proj_mat[2][1]}
        camera_up_worldspace = la.normalize(camera_up_worldspace)
        for &pv in pv {
            pv.position = camera_right_worldspace * pv.position.x + camera_up_worldspace * pv.position.y
        }

        pp := rs.player_particles
        i_ppos:[3]f32 = interpolated_player_pos(&gs.player_state, f32(interp_t))
        set_matrix_uniform(shst, "projection", &proj_mat)
        set_float_uniform(shst, "i_time", f32(time))
        set_vec3_uniform(shst, "player_pos", 1, &i_ppos)
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(pv[0]) * len(pv), &pv[0], gl.DYNAMIC_DRAW) 
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(pp[0]) * len(pp), &pp[0], gl.DYNAMIC_DRAW) 
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, PLAYER_PARTICLE_COUNT)
    }
    if EDIT && len(gs.editor_state.connections) > 0 {
        gl.BindVertexArray(rs.lines_vao)
        use_shader(shst, rs, .Outline)
        set_matrix_uniform(shst, "projection", &proj_mat)
        red := [3]f32{1.0, 0.0, 0.0}
        set_vec3_uniform(shst, "color", 1, &red)
        el := gs.editor_state.connections
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(el[0]) * len(el), &el[0], gl.DYNAMIC_DRAW)
        gl.DrawArrays(gl.LINES, 0, i32(len(el)))
    }
    // ================================
}

draw_shader_render_queue :: proc(rs: ^Render_State, shst: ^ShaderState, mode: u32) {
    queue := rs.shader_render_queues[shst.loaded_program_name]
    //fmt.println(queue)
    if len(queue) > 0 {
        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, rs.indirect_buffer)
        gl.BufferData(gl.DRAW_INDIRECT_BUFFER, size_of(queue[0]) * len(queue), raw_data(queue), gl.DYNAMIC_DRAW)
        gl.MultiDrawElementsIndirect(mode, gl.UNSIGNED_INT, nil, i32(len(queue)), 0)
    }
}

