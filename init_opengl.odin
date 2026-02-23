package main

import "base:runtime"
import "core:os"
import "core:fmt"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import SDL "vendor:sdl2"
import ft "shared:freetype"


init_opengl :: proc(window: ^SDL.Window) -> (gl_context: SDL.GLContext){
    SDL.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
    SDL.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 6)
    gl_context = SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(4, 6, SDL.gl_set_proc_address)
    return
}


init_opengl_text_rendering :: proc(bs: ^Buffer_State, perm_alloc: runtime.Allocator) {
    ft.init_free_type(&bs.ft_lib)
    ft.new_face(bs.ft_lib, "fonts/0xProtoNerdFont-Bold.ttf", 0, &bs.face)
    bs.char_tex_map = make(map[rune]Char_Tex, perm_alloc)
    ft.set_pixel_sizes(bs.face, 0, 256)
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    for c in 0..<128 {
        char_load_err: ft.Error
        when ODIN_OS == .Windows {
            char_load_err = ft.load_char(bs.face, u32(c), {ft.Load_Flag.Render})
        } else {
            char_load_err = ft.load_char(bs.face, u64(c), {ft.Load_Flag.Render})
        }
        if char_load_err != nil {
            fmt.eprintln(char_load_err)
        }
        new_tex: u32 
        gl.GenTextures(1, &new_tex)
        gl.BindTexture(gl.TEXTURE_2D, new_tex)
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            i32(bs.face.glyph.bitmap.width),
            i32(bs.face.glyph.bitmap.rows),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            bs.face.glyph.bitmap.buffer
        )
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        ct: Char_Tex = {
            id = new_tex,
            size = {i32(bs.face.glyph.bitmap.width), i32(bs.face.glyph.bitmap.rows)},
            bearing = {i32(bs.face.glyph.bitmap_left), i32(bs.face.glyph.bitmap_top)},
            next = u32(bs.face.glyph.advance.x)
        }
        bs.char_tex_map[rune(c)] = ct
    } 
}


init_opengl_mesh_rendering :: proc(bs: ^Buffer_State, ptcls: Particle_State, sr: ^Shape_Resources, perm_alloc: runtime.Allocator) {
    bs.ssbo_ids = make(map[Ssbo]u32, perm_alloc)

    // init buffers / VAOs ----------------
    gl.GenFramebuffers(1, &bs.postprocessing_fbo)
    gl.GenTextures(1, &bs.postprocessing_tcb)
    gl.GenRenderbuffers(1, &bs.postprocessing_rbo)

    gl.BindFramebuffer(gl.FRAMEBUFFER, bs.postprocessing_fbo)
    gl.BindTexture(gl.TEXTURE_2D, bs.postprocessing_tcb)  
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, WIDTH, HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, bs.postprocessing_tcb, 0)
    gl.BindRenderbuffer(gl.RENDERBUFFER, bs.postprocessing_rbo)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, WIDTH, HEIGHT)
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, bs.postprocessing_rbo)

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
        fmt.println("framebuffer gen error")
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    gl.GenBuffers(1, &bs.standard_ebo)
    gl.GenBuffers(1, &bs.player_fill_ebo)
    gl.GenBuffers(1, &bs.player_outline_ebo)
    gl.GenBuffers(1, &bs.spin_trails_ebo)

    gl.GenBuffers(1, &bs.indirect_buffer)
    
    gl.GenBuffers(1, &bs.combined_ubo)
    gl.GenBuffers(1, &bs.standard_ubo)
    gl.GenBuffers(1, &bs.shatter_delay_ubo)

    gl.GenBuffers(1, &bs.standard_vbo)
    gl.GenBuffers(1, &bs.player_vbo)
    gl.GenBuffers(1, &bs.particle_vbo)
    gl.GenBuffers(1, &bs.particle_pos_vbo)
    gl.GenBuffers(1, &bs.prev_particle_pos_vbo)
    gl.GenBuffers(1, &bs.trail_particle_vbo)
    gl.GenBuffers(1, &bs.prev_trail_particle_vbo)
    gl.GenBuffers(1, &bs.trail_particle_velocity_vbo)
    gl.GenBuffers(1, &bs.prev_trail_particle_velocity_vbo)
    gl.GenBuffers(1, &bs.background_vbo)
    gl.GenBuffers(1, &bs.text_vbo)
    gl.GenBuffers(1, &bs.editor_lines_vbo)
    gl.GenBuffers(1, &bs.spin_trails_vbo)

    gl.GenVertexArrays(1, &bs.standard_vao)
    gl.GenVertexArrays(1, &bs.particle_vao)
    gl.GenVertexArrays(1, &bs.trail_particle_vao)
    gl.GenVertexArrays(1, &bs.background_vao)
    gl.GenVertexArrays(1, &bs.lines_vao)
    gl.GenVertexArrays(1, &bs.player_vao)
    gl.GenVertexArrays(1, &bs.text_vao)
    gl.GenVertexArrays(1, &bs.spin_trails_vao)

    gl.GenTextures(1, &bs.dither_tex)

    gl.BindVertexArray(bs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.standard_vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.standard_ebo)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.standard_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

    gl.BindVertexArray(bs.player_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.player_vbo)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

    gl.BindVertexArray(bs.particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.particle_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, position))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, uv))
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.particle_pos_vbo)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, false, 0, 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.prev_particle_pos_vbo)
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, false, 0, 0)
    gl.VertexAttribDivisor(0, 0)
    gl.VertexAttribDivisor(1, 0)
    gl.VertexAttribDivisor(2, 1)
    gl.VertexAttribDivisor(3, 1)
    particle_vertices := PARTICLE_VERTICES
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.particle_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(particle_vertices[0]) * len(particle_vertices), &particle_vertices[0], gl.STATIC_DRAW) 
    particles := ptcls.player_burst_particles.particles
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.particle_pos_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(particles.values[0]) * PLAYER_SPIN_PARTICLE_COUNT, &particles.values[0], gl.STATIC_DRAW) 
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.prev_particle_pos_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(particles.values[0]) * PLAYER_SPIN_PARTICLE_COUNT, &particles.values[0], gl.STATIC_DRAW) 

    gl.BindVertexArray(bs.trail_particle_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.trail_particle_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(glm.vec4) * PLAYER_SPIN_PARTICLE_COUNT, nil, gl.STATIC_DRAW) 
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(glm.vec4), 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.prev_trail_particle_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(glm.vec4) * PLAYER_SPIN_PARTICLE_COUNT, nil, gl.STATIC_DRAW) 
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(glm.vec4), 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.trail_particle_velocity_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(glm.vec3) * PLAYER_SPIN_PARTICLE_COUNT, nil, gl.STATIC_DRAW) 
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(glm.vec3), 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.prev_trail_particle_velocity_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(glm.vec3) * PLAYER_SPIN_PARTICLE_COUNT, nil, gl.STATIC_DRAW) 
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 3, gl.FLOAT, false, size_of(glm.vec3), 0)

    bv := BACKGROUND_VERTICES
    gl.BindVertexArray(bs.background_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.background_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(bv[0]) * len(bv), &bv[0], gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex), offset_of(Quad_Vertex, uv))


    stv := sr.level_geometry[.SPIN_TRAIL].vertices
    sti := sr.level_geometry[.SPIN_TRAIL].indices
    gl.BindVertexArray(bs.spin_trails_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.spin_trails_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(stv[0]) * len(stv), &stv[0], gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.spin_trails_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(sti[0]) * len(sti), raw_data(sti), gl.STATIC_DRAW)

    gl.BindVertexArray(bs.text_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.text_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Quad_Vertex4) * 4, nil, gl.DYNAMIC_DRAW);
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Quad_Vertex4), offset_of(Quad_Vertex4, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex4), offset_of(Quad_Vertex4, uv))

    gl.BindVertexArray(bs.lines_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, bs.editor_lines_vbo)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 1, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, t))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, color))

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.combined_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Combined_Ubo), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 0, bs.combined_ubo, 0, size_of(Combined_Ubo))

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.standard_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Standard_Ubo), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 1, bs.standard_ubo, 0, size_of(Standard_Ubo))

    gl.BindBuffer(gl.UNIFORM_BUFFER, bs.shatter_delay_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(f32), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 2, bs.shatter_delay_ubo, 0, size_of(f32))

    ssbo_info := Ssbo_Info
    for ssbo in Ssbo {
        buf_id: u32 = 0
        gl.GenBuffers(1, &buf_id)
        gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, buf_id)
        gl.BufferData(gl.SHADER_STORAGE_BUFFER, ssbo_info[ssbo].type_sz * MAX_LEVEL_GEOMETRY_COUNT, nil, gl.STATIC_DRAW)
        gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, ssbo_info[ssbo].loc, buf_id)
        bs.ssbo_ids[ssbo] = buf_id
    }

    // load blue noise dither texture -----
    if dither_bin, err := os.read_entire_file("textures/blue_noise_64.png", perm_alloc); err == os.ERROR_NONE {
        gl.BindTexture(gl.TEXTURE_2D, bs.dither_tex)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0, gl.RGBA, gl.UNSIGNED_BYTE, &dither_bin[0])
    } 

    // load resource vertices/indices buffers
    element_array_vertices := make([dynamic]Vertex, context.temp_allocator)
    element_array_indices := make([dynamic]u32, context.temp_allocator)
    for shape in SHAPE {
        sd := sr.level_geometry[shape]
        sr.vertex_offsets[int(shape)] = u32(len(element_array_vertices))
        sr.index_offsets[int(shape)] = u32(len(element_array_indices))
        append(&element_array_indices, ..sd.indices)
        append(&element_array_vertices, ..sd.vertices)
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, bs.standard_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(element_array_vertices[0]) * len(element_array_vertices), raw_data(element_array_vertices), gl.STATIC_DRAW) 
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.standard_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(element_array_indices[0]) * len(element_array_indices), raw_data(element_array_indices), gl.STATIC_DRAW)

    pfi := sr.player_fill_indices
    poi := sr.player_outline_indices
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_outline_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(poi[0]) * len(poi), raw_data(poi), gl.STATIC_DRAW)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bs.player_fill_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(pfi[0]) * len(pfi), raw_data(pfi), gl.STATIC_DRAW)

    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}
