package main

import "core:fmt"
import "core:math"
import str "core:strings"
import gl "vendor:OpenGL"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import rnd "core:math/rand"
import tm "core:time"

PLAYER_PARTICLE_COUNT :: 40
I_MAT :: glm.mat4(1.0)
SHAPE_NAMES :: [?]string {"basic_cube", "weird", "triangle"}

QUAD_VERTICES :: [4]Vertex {
    {pos={-1, -1, -1}, uv={0, 0}, b_uv={0, 0}, normal={0, 0, 1}},
    {pos={-1, 1, -1}, uv={0, 1}, b_uv={0, 1}, normal={0, 0, 1}},
    {pos={1, 1, -1}, uv={1, 1}, b_uv={1, 1}, normal={0, 0, 1}},
    {pos={1, -1, -1}, uv={1, 0}, b_uv={1, 0}, normal={0, 0, 1}}
}

QUAD_INDICES :: [4]u32 {0, 1, 2, 3}

PARTICLE_VERTICES :: [4]glm.vec3 {
    {-0.3, -0.3, 0.0},
    {0.3, -0.3, 0.0},
    {-0.3, 0.3, 0.0},
    {0.3, 0.3, 0.0},
}

Render_State :: struct {
    standard_vao: u32,
    standard_ebo: u32,
    standard_vbo: u32,
    particle_vao: u32,
    particle_vbo: u32,
    particle_pos_vbo: u32,
    indirect_buffer: u32,
    transforms_ssbo: u32,
    z_widths_ssbo: u32,
    static_transforms: [dynamic]glm.mat4,
    player_particle_poss: [dynamic]glm.vec3,
    z_widths: [dynamic]f32,
    shader_queues: Shader_Queues,
    shader_render_queues: Shader_Render_Queues,
    player_particles: [PLAYER_PARTICLE_COUNT][3]f32
}

Render_Queue :: struct{
    transforms: [dynamic]glm.mat4,
    vertices: [dynamic]Vertex,
    indices: [dynamic]u32,
    commands: [dynamic]gl.DrawElementsIndirectCommand,
    z_widths: [dynamic]f32
}

Renderable :: struct{
    transform: glm.mat4,
    z_width: f32
}

Shader_Queues :: [ProgramName]map[string][dynamic]Renderable
Shader_Render_Queues :: [ProgramName]Render_Queue

load_geometry_data :: proc(gs: ^Game_State, ps: ^Physics_State) {
    for name in SHAPE_NAMES {
        if ok := load_blender_model(name, gs, ps); ok {
            fmt.println("loaded", name) 
        }
    }
}

init_render_buffers :: proc(gs: ^Game_State, rs: ^Render_State) {
    for shader in ProgramName {
        rs.shader_queues[shader] = make(map[string][dynamic]Renderable)
        for shape in SHAPE_NAMES {
            rs.shader_queues[shader][shape] = make([dynamic]Renderable)
        }
    }
    for shader in ProgramName {
        rq := rs.shader_render_queues[shader]
        rq.transforms = make([dynamic]glm.mat4)
        rq.indices = make([dynamic]u32)
        rq.vertices = make([dynamic]Vertex)
        rq.commands = make([dynamic]gl.DrawElementsIndirectCommand)
        rq.z_widths = make([dynamic]f32)
    }
    rs.static_transforms = make([dynamic]glm.mat4)
    rs.z_widths = make([dynamic]f32)
    rs.player_particle_poss = make([dynamic]glm.vec3)
    add_player_sphere_data(gs)
}

clear_render_queues :: proc(rs: ^Render_State) {
    for shader in ProgramName {
        for shape in SHAPE_NAMES {
            clear(&rs.shader_queues[shader][shape])
        }
    }
    for shader in ProgramName {
        rq := rs.shader_render_queues[shader]
        clear(&rq.transforms)
        clear(&rq.indices)
        clear(&rq.vertices)
        clear(&rq.commands)
        clear(&rq.z_widths)
        rs.shader_render_queues[shader] = rq
    }
}

free_render_buffers :: proc(rs: ^Render_State) {
    for shader in ProgramName {
        for shape in SHAPE_NAMES {
            delete(rs.shader_queues[shader][shape])
        }
        delete(rs.shader_queues[shader])
    }
    for shader in ProgramName {
        rq := rs.shader_render_queues[shader]
        delete(rq.transforms)
        delete(rq.indices)
        delete(rq.vertices)
        delete(rq.commands)
        delete(rq.z_widths)
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
    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenVertexArrays(1, &rs.particle_vao)

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
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 0, 0)
    gl.VertexAttribDivisor(0, 0)
    gl.VertexAttribDivisor(1, 1)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    return true
}

init_level_render_data :: proc(gs: ^Game_State, shst: ^ShaderState, rs: ^Render_State) {
    for lg in gs.level_geometry {
        trans_mat := trans_to_mat4(lg.transform)
        append(&rs.static_transforms, trans_mat)
        max_z := min(f32)
        min_z := max(f32)
        for v in gs.level_resources[lg.shape].vertices {
            new_pos := trans_mat * [4]f32{v.pos[0], v.pos[1], v.pos[2], 1.0}
            max_z = max(new_pos.z, max_z)
            min_z = min(new_pos.z, min_z)
        }
        append(&rs.z_widths, max_z - min_z)
    }
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
            if lg_idx > len(rs.static_transforms) - 1 {
                append(&rs.static_transforms, trans_mat) 
                append(&rs.z_widths, max_z - min_z)
            } else {
                rs.static_transforms[lg_idx] = trans_mat
                rs.z_widths[lg_idx] = max_z - min_z
            }
        }
    }
    if gs.deleted_entity != -1 {
        ordered_remove(&rs.static_transforms, gs.deleted_entity)
        gs.deleted_entity = -1
    }
    clear(&gs.dirty_entities)

}

update_player_particles :: proc(rs: ^Render_State, time: f32) {
    for &pp, pp_idx in rs.player_particles {
        h_angle := 3.14 * math.sin((time / 4000 + f32(pp_idx) * 200) * 3.14) * 4
        v_angle := 3.14 * math.sin((time / 3600 + f32(pp_idx) * 200) * 3.14) * 4
        xz := SPHERE_RADIUS * math.cos(v_angle)
        x := xz * math.cos(h_angle)
        z := xz * math.sin(h_angle)
        y := SPHERE_RADIUS * math.sin(v_angle)
        pp = {x, y, z} * 1.5
    }
}

render :: proc(gs: ^Game_State, rs: ^Render_State, shst: ^ShaderState, ps: ^Physics_State, time: f64, interp_t: f64) {
    clear_render_queues(rs)

    // organize level geometry by shader -> shape
    for lg, lg_idx in gs.level_geometry {
        for shader in lg.shaders {
            append(&rs.shader_queues[shader][lg.shape],
                Renderable{rs.static_transforms[lg_idx], rs.z_widths[lg_idx]})
        }
    }

    // add level geometry to render queues
    for queue, shader in rs.shader_queues {
        render_queue := rs.shader_render_queues[shader]
        for shape, renderables in queue {
            if len(renderables) == 0 do continue
            sd := gs.level_resources[shape]
            command: gl.DrawElementsIndirectCommand = {
                u32(len(sd.indices)),
                u32(len(renderables)),
                u32(len(render_queue.indices)),
                u32(len(render_queue.vertices)),
                u32(len(render_queue.transforms)),

            }
            for r in renderables {
                append(&render_queue.transforms, r.transform)
                append(&render_queue.z_widths, r.z_width)
            }
            append(&render_queue.vertices, ..sd.vertices)
            append(&render_queue.indices, ..sd.indices)
            append(&render_queue.commands, command)
        }
        rs.shader_render_queues[shader] = render_queue
    }

    // add player to render queue
    player_mat := interpolated_player_matrix(&gs.player_state, f32(interp_t))
    player_rq := rs.shader_render_queues[.Player]
    append(&player_rq.transforms, player_mat)
    append(&player_rq.vertices, ..gs.player_geometry.vertices[:])
    append(&player_rq.indices, ..gs.player_geometry.indices)
    append(&player_rq.commands, gl.DrawElementsIndirectCommand{
        u32(len(gs.player_geometry.indices)), 1, 0, 0, 0
    })
    rs.shader_render_queues[.Player] = player_rq


    // add player particles to render queue


    //fmt.println("data transform time:", tm.since(data_transform_start))

    // execute draw queues

    proj_mat: glm.mat4
    if EDIT {
        proj_mat = construct_camera_matrix(&gs.camera_state)
    } else {
        proj_mat = interpolated_camera_matrix(&gs.camera_state, f32(interp_t))
    }

    gl.BindVertexArray(rs.standard_vao)
    gl.Disable(gl.DEPTH_TEST)
    gl.Disable(gl.CULL_FACE)
    bqv := QUAD_VERTICES
    bqi := QUAD_INDICES
    use_shader(shst, rs, .Background)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(bqv[0]) * len(bqv), &bqv[0], gl.DYNAMIC_DRAW) 
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(bqi[0]) * len(bqi), &bqi[0], gl.DYNAMIC_DRAW)
    gl.DrawElements(gl.QUADS, len(bqi), gl.UNSIGNED_INT, nil)
    gl.Enable(gl.DEPTH_TEST)
    gl.Enable(gl.CULL_FACE)

    use_shader(shst, rs, .Player)
    p_color: [3]f32 = gs.player_state.dashing ? {1.0, 1.0, 0} : {1.0, 0.0, 0.5}
    set_matrix_uniform(shst, "projection", &proj_mat)
    set_float_uniform(shst, "i_time", f32(time) / 1000)
    set_vec3_uniform(shst, "p_color", 1, &p_color)
    draw_shader_render_queue(rs, shst, gl.TRIANGLES)

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
        set_float_uniform(shst, "sonar_time", f32(gs.player_state.sonar_time) / 1000)
        set_matrix_uniform(shst, "projection", &proj_mat)
        draw_shader_render_queue(rs, shst, gl.PATCHES)
    }

    // PARTICLE DRAW TEST ZONE=========
    gl.BindVertexArray(rs.particle_vao)
    ppv := PARTICLE_VERTICES
    ppp := rs.player_particles
    i_ppos:[3]f32 = interpolated_player_pos(&gs.player_state, f32(interp_t))
    use_shader(shst, rs, .Player_Particle)
    set_matrix_uniform(shst, "projection", &proj_mat)
    set_vec3_uniform(shst, "player_pos", 1, &i_ppos)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(ppv[0]) * len(ppv), &ppv[0], gl.DYNAMIC_DRAW) 
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.particle_pos_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(ppp[0]) * len(ppp), &ppp[0], gl.DYNAMIC_DRAW) 
    gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, PLAYER_PARTICLE_COUNT)
    // ================================
}

draw_shader_render_queue :: proc(rs: ^Render_State, shst: ^ShaderState, mode: u32) {
    queue := rs.shader_render_queues[shst.loaded_program_name]
    if len(queue.commands) > 0 {
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(queue.vertices[0]) * len(queue.vertices), raw_data(queue.vertices), gl.DYNAMIC_DRAW) 
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(queue.indices[0]) * len(queue.indices), raw_data(queue.indices), gl.DYNAMIC_DRAW)
        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, rs.indirect_buffer)
        gl.BufferData(gl.DRAW_INDIRECT_BUFFER, size_of(queue.commands[0]) * len(queue.commands), raw_data(queue.commands), gl.DYNAMIC_DRAW)
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.transforms_ssbo)
        gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(queue.transforms[0]) * len(queue.transforms), raw_data(queue.transforms), gl.DYNAMIC_DRAW)
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, rs.transforms_ssbo)
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rs.z_widths_ssbo)
        gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(queue.z_widths[0]) * len(queue.z_widths), raw_data(queue.z_widths), gl.DYNAMIC_DRAW)
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, rs.z_widths_ssbo)
        gl.MultiDrawElementsIndirect(mode, gl.UNSIGNED_INT, nil, i32(len(queue.commands)), 0)
    }
}

