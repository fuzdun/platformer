package main
import la "core:math/linalg"

extrapolate_state_attributes :: proc(is: Input_State, pls: Player_State, new_jump_pressed_time: f32, elapsed_time: f32) -> Intra_Update_Attributes {
    // directional input
    // -------------------------------------------
    input_x: f32 = 0.0
    input_z: f32 = 0.0
    input_x = 0
    input_z = 0
    if is.left_pressed  do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed    do input_z -= 1
    if is.down_pressed  do input_z += 1
    input_dir: [2]f32
    if is.hor_axis != 0 || is.vert_axis != 0 {
        input_dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    } else {
        input_dir = la.normalize0([2]f32{input_x, input_z})
    }
    got_dir_input := input_dir != 0
    got_fwd_input := la.dot(la.normalize0(pls.velocity.xz), input_dir) > 0.80

    // surface contact
    // -------------------------------------------
    cts := pls.contact_state
    on_surface := cts.state == .ON_GROUND || cts.state == .ON_SLOPE || cts.state == .ON_WALL
    normalized_contact_ray := la.normalize(cts.contact_ray) 

    // jump
    // -------------------------------------------
    small_hopped := abs(cts.touch_time - new_jump_pressed_time) < BUNNY_WINDOW || 
        (
            abs(pls.slide_state.slide_end_time - new_jump_pressed_time) < BUNNY_WINDOW &&
            elapsed_time - new_jump_pressed_time < BUNNY_WINDOW
        )

    bunny_hopped := elapsed_time - pls.dash_hop_debounce_t > BUNNY_DASH_DEBOUNCE &&
                    on_surface && pls.spin_state.spinning &&
                    (pls.hops_remaining > 0 || INFINITE_HOP)

    should_jump := is.z_pressed && pls.can_press_jump || bunny_hopped || small_hopped

    ground_jump_coyote_time_active := elapsed_time - cts.left_ground < COYOTE_TIME
    slope_jump_coyote_time_active  := elapsed_time - cts.left_slope  < COYOTE_TIME
    wall_jump_coyote_time_active   := elapsed_time - cts.left_wall   < COYOTE_TIME

    ground_jumped := should_jump && (cts.state == .ON_GROUND || ground_jump_coyote_time_active)
    slope_jumped  := should_jump && (cts.state == .ON_SLOPE  || slope_jump_coyote_time_active) 
    wall_jumped   := should_jump && (cts.state == .ON_WALL   || wall_jump_coyote_time_active)

    jumped := ground_jumped || slope_jumped || wall_jumped

    grounded := cts.state == .ON_GROUND || cts.state == .ON_SLOPE
    right_vec := grounded ? pls.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? pls.ground_z : [3]f32{0, 0, -1}

    move_spd := SLOW_ACCEL
    if cts.state == .ON_SLOPE {
        // move_spd = SLOPE_SPEED
    } else if cts.state == .IN_AIR {
        if pls.spin_state.spinning {
            // move_spd = AIR_SPIN_ACCEL
        } else {
            // move_spd = AIR_ACCEL
        }
    }
    if got_fwd_input {
        flat_speed := la.length(pls.velocity.xz)
        if flat_speed > FAST_CUTOFF {
            move_spd = FAST_ACCEL

        } else if flat_speed > MED_CUTOFF {
            move_spd = MED_ACCEL
        }
    }

    return {
        input_x = input_x,
        input_z = input_z,
        input_dir = input_dir, 
        got_dir_input = got_dir_input,
        got_fwd_input = got_fwd_input,
        on_surface = on_surface,
        normalized_contact_ray = normalized_contact_ray,
        small_hopped = small_hopped,
        bunny_hopped = bunny_hopped,
        ground_jumped = ground_jumped,
        slope_jumped = slope_jumped,
        wall_jumped = wall_jumped,
        jumped = jumped,
        grounded = grounded,
        right_vec = right_vec,
        fwd_vec = fwd_vec,
        move_spd = move_spd
    }
}
