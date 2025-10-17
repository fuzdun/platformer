package main

import "core:sort"
import "core:encoding/xml/example"
import "core:fmt"
import "core:mem"
import "core:os"
import glm "core:math/linalg/glsl"
import str "core:strings"
import SDL "vendor:sdl2"
import TTF "vendor:sdl2/ttf"
import  "core:strconv"
import gl "vendor:OpenGL"
import ft "shared:freetype"
import imgui "shared:odin-imgui"
import imsdl "shared:odin-imgui/imgui_impl_sdl2"
import imgl "shared:odin-imgui/imgui_impl_opengl3"

MAX_LEVEL_GEOMETRY_COUNT :: 2000

EDIT :: #config(EDIT, false)
PERF_TEST :: #config(PERF_TEST, false)
PLAYER_DRAW :: #config(PLAYER_DRAW, false)

WIDTH :: 1920.0
HEIGHT :: 1080.0
FULLSCREEN :: true
// WIDTH :: 900
// HEIGHT :: 900
// FULLSCREEN :: false
TARGET_FRAME_RATE :: 60.0
FIXED_DELTA_TIME :: f32(1.0 / TARGET_FRAME_RATE)
FORCE_EXTERNAL_MONITOR :: false

TITLE :: "platformer"

quit_app := false

main :: proc () {
    controller : ^SDL.GameController
    // debug mem leak detector
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
        defer {
            if len(track.allocation_map) > 0{
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map)) 
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v vytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    
    //create SDL window
    if SDL.Init({.VIDEO, .GAMECONTROLLER}) < 0 {
        fmt.println("SDL could not initialize")
    }
    SDL.GL_SetSwapInterval(1)

    if TTF.Init() == -1 {
        fmt.eprintln("failed to initialize TTF:", TTF.GetError())
    }

    for i in 0..<SDL.NumJoysticks() {
        if (SDL.IsGameController(i)) {
            controller = SDL.GameControllerOpen(i)
        }
    }

    window: ^SDL.Window

    if FORCE_EXTERNAL_MONITOR {
        external_display_rect: SDL.Rect
        SDL.GetDisplayBounds(1, &external_display_rect)

        window = SDL.CreateWindow(
            TITLE,
            external_display_rect.x,
            external_display_rect.y,
            external_display_rect.w,
            external_display_rect.h,
            {.OPENGL}
        )

    } else {
        window = SDL.CreateWindow(
            TITLE,
            0,
            0,
            WIDTH,
            HEIGHT,
            {.OPENGL}
        )
    }

    if window == nil {
        fmt.eprintln("Failed to create window")
    }
    defer SDL.DestroyWindow(window)
    if FULLSCREEN {
        SDL.SetWindowFullscreen(window, SDL.WINDOW_FULLSCREEN)
    }

    // hook up OpenGL
    SDL.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
    SDL.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 6)
    gl_context := SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    gl.load_up_to(4, 6, SDL.gl_set_proc_address)

    // allocate / defer deallocate state structs
    lgs: Level_Geometry_State; defer delete(lgs)
    ts:  Time_State;           defer free_time_state(&ts)
    is:  Input_State;          defer free_input_state(&is)
    cs:  Camera_State;         defer free_camera_state(&cs) 
    es:  Editor_State;         defer free_editor_state(&es)
    phs: Physics_State;        defer free_physics_state(&phs)
    shs: Shader_State;         defer free_shader_state(&shs)
    rs:  Render_State;         defer free_render_state(&rs)
    pls: Player_State;         defer free_player_state(&pls)
    sr:  Shape_Resources;      defer free_level_resources(&sr)
    szs: Slide_Zone_State;     defer free_slide_zone_state(&szs)

    // init game state

    szs.entities = make(#soa[dynamic]Obb)

    cs.position = {10, 60, 300}

    es.y_rot = -.25
    es.zoom = 400
    es.connections = make([dynamic]Connection)

    ts.time_mult = 1.0

    phs.debug_render_queue.vertices = make([dynamic]Vertex)
    phs.static_collider_vertices = make([dynamic][3]f32)
    for pn in ProgramName {
        phs.debug_render_queue.indices[pn] = make([dynamic]u16)
    }

    shs.active_programs = make(map[ProgramName]Active_Program)

    add_player_sphere_data(&rs.player_geometry.vertices, &rs.player_fill_indices, &rs.player_outline_indices)

    pls.contact_state.state = .IN_AIR
    pls.position = INIT_PLAYER_POS
    pls.dash_state.can_dash = true
    pls.slide_state.slide_end_time = -SLIDE_COOLDOWN
    pls.slide_state.can_slide = true
    pls.can_press_jump = false
    pls.contact_state.ground_x = {1, 0, 0}
    pls.contact_state.ground_z = {0, 0, -1}
    pls.contact_state.touch_time = -1000.0
    pls.spike_compression = 1.0
    pls.crunch_time = -10000.0;
    pls.crunch_pts = make([dynamic][4]f32); defer delete(pls.crunch_pts)
    pls.hurt_t = -5000.0
    pls.broke_t = -5000.0
    ring_buffer_init(&pls.trail, [3]f32{0, 0, 0})

    // init level resources
    for shape in SHAPE {
        if ok := load_glb_model(shape, &sr, &phs); ok {
            fmt.println("loaded", shape) 
        }
    }

    // init shader programs
    dir := "shaders/"
    ext := ".glsl"
    for config, program in PROGRAM_CONFIGS {
        shaders := make([]u32, len(config.pipeline))
        defer delete(shaders)
        for filename, shader_i in config.pipeline {
            type := config.shader_types[shader_i]
            filename := str.concatenate({dir, filename, ext})
            defer delete(filename)
            shader_string, shader_ok := os.read_entire_file(filename)
            defer delete(shader_string)
            if !shader_ok {
                fmt.eprintln("failed to read shader file:", shader_string)
            }
            shader_id, ok := gl.compile_shader_from_source(string(shader_string), type)
            if !ok {
                fmt.eprintln("failed to compile shader:", filename)
            }
            shaders[shader_i] = shader_id
        }

        program_id, program_ok := gl.create_and_link_program(shaders)
        if !program_ok {
            fmt.eprintln("program link failed:", program)
            //return false
        }
        shs.active_programs[program] = {program_id, make(map[string]i32)}
        prog := shs.active_programs[program]
        for uniform in config.uniforms {
            cstr_name := str.clone_to_cstring(uniform); defer delete(cstr_name)
            prog.locations[uniform] = gl.GetUniformLocation(program_id, cstr_name)
            shs.active_programs[program] = prog
        }
    }

    // init text rendering
    ft.init_free_type(&rs.ft_lib)
    ft.new_face(rs.ft_lib, "fonts/0xProtoNerdFont-Bold.ttf", 0, &rs.face)
    rs.char_tex_map = make(map[rune]Char_Tex)
    ft.set_pixel_sizes(rs.face, 0, 256)
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    for c in 0..<128 {
        if char_load_err := ft.load_char(rs.face, u64(c), {ft.Load_Flag.Render}); char_load_err != nil {
            fmt.eprintln(char_load_err)
        }
        new_tex: u32 
        gl.GenTextures(1, &new_tex)
        gl.BindTexture(gl.TEXTURE_2D, new_tex)
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            i32(rs.face.glyph.bitmap.width),
            i32(rs.face.glyph.bitmap.rows),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            rs.face.glyph.bitmap.buffer
        )
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        ct: Char_Tex = {
            id = new_tex,
            size = {i32(rs.face.glyph.bitmap.width), i32(rs.face.glyph.bitmap.rows)},
            bearing = {i32(rs.face.glyph.bitmap_left), i32(rs.face.glyph.bitmap_top)},
            next = u32(rs.face.glyph.advance.x)
        }
        // fmt.println(ct)
        rs.char_tex_map[rune(c)] = ct
    } 

    //if !init_shaders(ss) {
    //    fmt.eprintln("shader init failed")
    //    return false
    //}

    // init mesh rendering
    
    gl.GenFramebuffers(1, &rs.postprocessing_fbo)
    gl.GenTextures(1, &rs.postprocessing_tcb)
    gl.GenRenderbuffers(1, &rs.postprocessing_rbo)

    gl.BindFramebuffer(gl.FRAMEBUFFER, rs.postprocessing_fbo)
    gl.BindTexture(gl.TEXTURE_2D, rs.postprocessing_tcb)  
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, WIDTH, HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, rs.postprocessing_tcb, 0)
    gl.BindRenderbuffer(gl.RENDERBUFFER, rs.postprocessing_rbo)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, WIDTH, HEIGHT)
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rs.postprocessing_rbo)

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
        fmt.println("framebuffer gen error")
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    gl.GenBuffers(1, &rs.standard_ebo)
    gl.GenBuffers(1, &rs.player_fill_ebo)
    gl.GenBuffers(1, &rs.player_outline_ebo)

    gl.GenBuffers(1, &rs.indirect_buffer)
    
    gl.GenBuffers(1, &rs.common_ubo)
    gl.GenBuffers(1, &rs.dash_ubo)
    gl.GenBuffers(1, &rs.ppos_ubo)
    gl.GenBuffers(1, &rs.tess_ubo)
    gl.GenBuffers(1, &rs.transforms_ubo)
    gl.GenBuffers(1, &rs.z_widths_ubo)
    gl.GenBuffers(1, &rs.shatter_ubo)
    gl.GenBuffers(1, &rs.transparencies_ubo)

    gl.GenBuffers(1, &rs.standard_vbo)
    gl.GenBuffers(1, &rs.player_vbo)
    gl.GenBuffers(1, &rs.particle_vbo)
    gl.GenBuffers(1, &rs.particle_pos_vbo)
    gl.GenBuffers(1, &rs.background_vbo)
    gl.GenBuffers(1, &rs.text_vbo)
    gl.GenBuffers(1, &rs.editor_lines_vbo)

    gl.GenVertexArrays(1, &rs.standard_vao)
    gl.GenVertexArrays(1, &rs.particle_vao)
    gl.GenVertexArrays(1, &rs.background_vao)
    gl.GenVertexArrays(1, &rs.lines_vao)
    gl.GenVertexArrays(1, &rs.player_vao)
    gl.GenVertexArrays(1, &rs.text_vao)

    gl.GenTextures(1, &rs.dither_tex)

    gl.BindVertexArray(rs.standard_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))

    gl.BindVertexArray(rs.player_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.player_vbo)
    gl.PatchParameteri(gl.PATCH_VERTICES, 3);
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
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

    gl.BindVertexArray(rs.text_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.text_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Quad_Vertex4) * 4, nil, gl.DYNAMIC_DRAW);
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(Quad_Vertex4), offset_of(Quad_Vertex4, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Quad_Vertex4), offset_of(Quad_Vertex4, uv))

    gl.BindVertexArray(rs.lines_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rs.editor_lines_vbo)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, position))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 1, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, t))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Line_Vertex), offset_of(Line_Vertex, color))

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.common_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Common_Ubo), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 0, rs.common_ubo, 0, size_of(Common_Ubo))

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.dash_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Dash_Ubo), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 1, rs.dash_ubo, 0, size_of(Dash_Ubo))

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.ppos_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(glm.vec4), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 2, rs.ppos_ubo, 0, size_of(glm.vec4))

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.tess_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Tess_Ubo), nil, gl.STATIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 3, rs.tess_ubo, 0, size_of(Tess_Ubo))

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.transforms_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(glm.mat4) * MAX_LEVEL_GEOMETRY_COUNT, nil, gl.DYNAMIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 4, rs.transforms_ubo, 0, size_of(glm.mat4) * MAX_LEVEL_GEOMETRY_COUNT)

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.z_widths_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Z_Width_Ubo) * MAX_LEVEL_GEOMETRY_COUNT, nil, gl.DYNAMIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 5, rs.z_widths_ubo, 0, size_of(Z_Width_Ubo) * MAX_LEVEL_GEOMETRY_COUNT)

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.shatter_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Shatter_Ubo) * MAX_LEVEL_GEOMETRY_COUNT, nil, gl.DYNAMIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 6, rs.shatter_ubo, 0, size_of(Shatter_Ubo) * MAX_LEVEL_GEOMETRY_COUNT)

    gl.BindBuffer(gl.UNIFORM_BUFFER, rs.transparencies_ubo)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(Transparency_Ubo) * MAX_LEVEL_GEOMETRY_COUNT, nil, gl.DYNAMIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 7, rs.transparencies_ubo, 0, size_of(Transparency_Ubo) * MAX_LEVEL_GEOMETRY_COUNT)

    gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

    if dither_bin, read_success := os.read_entire_file("textures/blue_noise_64.png"); read_success {
        defer delete(dither_bin)
        gl.BindTexture(gl.TEXTURE_2D, rs.dither_tex)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0, gl.RGBA, gl.UNSIGNED_BYTE, &dither_bin[0])
    }

    {
        vertices := make([dynamic]Vertex); defer delete(vertices)
        indices := make([dynamic]u32); defer delete(indices)
        for shape in SHAPE {
            sd := sr[shape]
            rs.vertex_offsets[int(shape)] = u32(len(vertices))
            rs.index_offsets[int(shape)] = u32(len(indices))
            append(&indices, ..sd.indices)
            append(&vertices, ..sd.vertices)
        }
        append(&indices, ..rs.player_geometry.indices)
        append(&vertices, ..rs.player_geometry.vertices)
        pv := rs.player_geometry.vertices 
        gl.BindBuffer(gl.ARRAY_BUFFER, rs.standard_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW) 
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.standard_ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)

        pfi := rs.player_fill_indices
        poi := rs.player_outline_indices
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_outline_ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(poi[0]) * len(poi), raw_data(poi), gl.STATIC_DRAW)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rs.player_fill_ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(pfi[0]) * len(pfi), raw_data(pfi), gl.STATIC_DRAW)
    }

    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.DEPTH_TEST)
    gl.LineWidth(5)

    // load level data
    loaded_level_geometry := load_level_geometry(sr, &phs, &rs, &szs, "test_level")
    defer delete(loaded_level_geometry)
    num_entities := len(loaded_level_geometry) 

    // sort level data
    lgs = sort_lgs(loaded_level_geometry)
    add_geometry_to_physics(&phs, &szs, lgs)

    dynamic_lgs := make(#soa[dynamic]Level_Geometry)
    defer delete(dynamic_lgs)

    if EDIT {
        for lg in lgs {
            append(&dynamic_lgs, lg)
        }

        // imgui init
        imgui.create_context()
        imgui.style_colors_dark()
        io := imgui.get_io()
        // io.config_flags |= {imgui.Config_Flag.Nav_Enable_Keyboard}
        // io.config_flags |= {imgui.Config_Flag.Nav_Enable_Gamepad}
        io.config_flags |= {imgui.Config_Flag.Docking_Enable}

        imsdl.init_for_open_gl(window, gl_context)
        imgl.init()
    }
    
    
    // start frame loop
    clocks_per_second := i64(SDL.GetPerformanceFrequency())
    target_frame_clocks := clocks_per_second / TARGET_FRAME_RATE
    max_deviation := clocks_per_second / 5000

    snap_hz: i64 = 60
    current_display_mode: SDL.DisplayMode
    if SDL.GetCurrentDisplayMode(0, &current_display_mode) == 0 {
        snap_hz = i64(current_display_mode.refresh_rate)
    }
    snap_hz = i64(clocks_per_second) / snap_hz
    snap_vals : [8]i64 = { snap_hz, snap_hz * 2, snap_hz * 3, snap_hz * 4, snap_hz * 5, snap_hz * 6, snap_hz * 7, snap_hz * 8 }
    
    frame_time_buffer : RingBuffer(4, i64)
    ring_buffer_init(&frame_time_buffer, target_frame_clocks)

    current_time, previous_time, delta_time, averager_res, accumulator : i64
    previous_time = i64(SDL.GetPerformanceCounter())

    resync := true
    quit_handler :: proc () { quit_app = true }

    for !quit_app {
        if quit_app do break

        elapsed_time := f64(SDL.GetTicks())
        // elapsed_time := f64(SDL.GetTicks()) * 0.1

        current_time = i64(SDL.GetPerformanceCounter())
        delta_time = current_time - previous_time
        previous_time = current_time

        if delta_time > target_frame_clocks * 8 {
            delta_time = target_frame_clocks
        }
        delta_time = max(0, delta_time)

        for val in snap_vals {
            if abs(delta_time - val) < max_deviation {
                delta_time = val
                break
            }
        }

        ring_buffer_push(&frame_time_buffer, delta_time)
        delta_time = ring_buffer_average(frame_time_buffer)
        averager_res += delta_time % 4 
        delta_time += averager_res / 4
        averager_res %= 4

        accumulator += delta_time

        if accumulator > target_frame_clocks * 8 {
            resync = true
        }

        if(resync) {
            accumulator = 0;
            delta_time = target_frame_clocks;
            resync = false;
        }

        // Handle input
        process_input(&is, quit_handler)

        for accumulator >= target_frame_clocks {
            // Fixed update
            if EDIT {
                editor_update(&dynamic_lgs, sr, &es, &cs, is, &rs, &phs, FIXED_DELTA_TIME)
            } else {
                game_update(&lgs, is, &pls, phs, &cs, &ts, &szs, f32(elapsed_time), FIXED_DELTA_TIME * ts.time_mult)
            }
            accumulator -= target_frame_clocks 
        }

        // Render
        draw_slice := EDIT ? dynamic_lgs[:] : lgs[:]
        draw(draw_slice, sr, pls, &rs, &shs, &phs, &cs, is, es, szs, elapsed_time, f64(accumulator) / f64(target_frame_clocks))
        if EDIT {
            imgl.new_frame()
            imsdl.new_frame()
            imgui.new_frame()

            imgui.begin("Level Editor")
            imgui.text("Level Geometry")
            imgui.begin_child("Scrolling")
            {
                for lg, lg_idx in dynamic_lgs {
                    color: imgui.Vec4 = es.selected_entity == lg_idx ? {1, 0, 0, 1} : {1, 1, 1, 1}
                    buf: [4]byte
                    num_string := strconv.itoa(buf[:], lg_idx)
                    shape_string := SHAPE_NAME[lg.shape]
                    display_name := str.concatenate({num_string, ": ", shape_string})
                    imgui.text_colored(color, str.unsafe_string_to_cstring(display_name))
                    if imgui.is_item_clicked(imgui.Mouse_Button.Left) {
                        es.selected_entity = lg_idx 
                    }
                }
            }
            imgui.end_child()
            imgui.end()

            // imgui.show_demo_window()
            imgui.render()
            imgl.render_draw_data(imgui.get_draw_data())
        } else {
        }

        SDL.GL_SwapWindow(window)
    }

    if EDIT {
        imgl.shutdown()
        imsdl.shutdown()
        imgui.destroy_context()
    }
}

