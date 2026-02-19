package main

import la "core:math/linalg"

Action_Triggers :: struct {
    jump: bool,
    jump_button_pressed: bool,
    jump_pressed_time: f32,

    ground_jump: bool,
    slope_jump: bool,
    wall_jump: bool,

    small_hop: bool,
    bunny_hop: bool,

    spin: bool,
    dash: bool,
    slide: bool,

    move: [2]f32,
    fwd_move: bool,
    wall_detach_held: f32,

    slide_zone: bool,

    restart: bool,
    checkpoint: bool
}

get_player_action_triggers :: proc(
    input: Input_Attributes,
    pls: Player_State,
    szs: Slide_Zone_State,
    elapsed_time: f32,
    delta_time: f32
) -> (out: Action_Triggers) {
    cts := pls.contact_state
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL

    out.jump_pressed_time = pls.jump_pressed_time
    if input.jump_pressed && !pls.jump_held {
        out.jump_pressed_time = elapsed_time
    }
    out.jump_button_pressed = input.jump_pressed

    hop_valid := out.jump_pressed_time > pls.last_hop + BUNNY_WINDOW * 2
    if hop_valid && (
        abs(cts.touch_time - out.jump_pressed_time) < BUNNY_WINDOW ||
        abs(pls.slide_state.slide_end_time - out.jump_pressed_time) < BUNNY_WINDOW
    ) {
        out.small_hop = true
    }

    out.bunny_hop = pls.mode == .Normal && on_surface && pls.spin_state.spin_amt > 0 &&
                    (pls.hops_remaining > 0 || INFINITE_HOP)

    should_jump := (input.jump_pressed && pls.jump_enabled) || out.bunny_hop || out.small_hop

    ground_jump_coyote_time_active := elapsed_time - cts.left_ground < COYOTE_TIME
    slope_jump_coyote_time_active  := elapsed_time - cts.left_slope  < COYOTE_TIME
    wall_jump_coyote_time_active   := elapsed_time - cts.left_wall   < COYOTE_TIME

    out.ground_jump = should_jump && (cts.state == .ON_GROUND || ground_jump_coyote_time_active)
    out.slope_jump  = should_jump && (cts.state == .ON_SLOPE  || slope_jump_coyote_time_active) 
    out.wall_jump   = should_jump && (cts.state == .ON_WALL   || wall_jump_coyote_time_active)

    out.jump = out.ground_jump || out.slope_jump || out.wall_jump

    out.move = input.dir
    out.fwd_move = la.dot(la.normalize0(pls.velocity.xz), input.dir) > 0.80

    normalized_contact_ray := la.normalize(cts.contact_ray) 
    out.wall_detach_held = pls.wall_detach_held_t
    if cts.state == .ON_WALL {
        if la.dot([3]f32{input.dir.x, 0, input.dir.y}, normalized_contact_ray) >= 0 {
            out.wall_detach_held = 0 
        } else {
            out.wall_detach_held += delta_time * 1000.0
        }

    } else {
        out.wall_detach_held = 0
    }

    out.spin = input.spin_pressed && !on_surface
    out.dash = input.action_pressed && pls.dash_enabled && !on_surface && pls.velocity != 0
    out.slide = input.action_pressed &&  pls.slide_enabled && on_surface && pls.velocity != 0

    out.slide_zone = len(szs.intersected) > 0

    out.restart = input.restart_pressed
    out.checkpoint = pls.position.y < -100
    return
}
