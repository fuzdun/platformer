package main

import ft "shared:freetype"

Buffer_State :: struct {
    postprocessing_fbo: u32,
    postprocessing_tcb: u32,
    postprocessing_rbo: u32,

    ft_lib: ft.Library,
    face: ft.Face,

    char_tex_map: map[rune]Char_Tex,

    standard_vao: u32,
    particle_vao: u32,
    trail_particle_vao: u32,
    background_vao: u32,
    lines_vao: u32,
    text_vao: u32,
    player_vao: u32,
    spin_trails_vao: u32,

    standard_ebo: u32,
    background_ebo: u32,
    player_fill_ebo: u32,
    player_outline_ebo: u32,
    spin_trails_ebo: u32,

    standard_vbo: u32,
    player_vbo: u32,
    particle_vbo: u32,
    prev_particle_pos_vbo: u32,
    trail_particle_vbo: u32,
    prev_trail_particle_vbo: u32,
    trail_particle_velocity_vbo: u32,
    prev_trail_particle_velocity_vbo: u32,
    particle_pos_vbo: u32,
    background_vbo: u32,
    editor_lines_vbo: u32,
    text_vbo: u32,
    spin_trails_vbo: u32,

    indirect_buffer: u32,

    combined_ubo: u32,
    standard_ubo: u32,

    dither_tex: u32,

    ssbo_ids: map[Ssbo]u32
}

