package main

import la "core:math/linalg"
import "core:math"

Player_State_Attributes :: struct {
    input_x: f32,
    input_z: f32,
    input_dir: [2]f32,
    got_dir_input: bool,
    got_fwd_input: bool,
    on_surface: bool,
    normalized_contact_ray: [3]f32,
    small_hop_triggered: bool,
    bunny_hop_triggered: bool,
    ground_jump_triggered: bool,
    slope_jump_triggered: bool,
    wall_jump_triggered: bool,
    jump_triggered: bool,
    grounded: bool,
    is_hurt: bool,
    in_slide_zone: bool,
    right_vec: [3]f32,
    fwd_vec: [3]f32,
    move_spd: f32,
    sent_to_checkpoint: bool
}

get_player_state_attributes :: proc(
    pls: Player_State,
    is: Input_State,
    szs: Slide_Zone_State,
    new_jump_pressed_time: f32,
    elapsed_time: f32
) -> Player_State_Attributes {

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
    small_hop_triggered := abs(cts.touch_time - new_jump_pressed_time) < BUNNY_WINDOW || 
        (
            abs(pls.slide_state.slide_end_time - new_jump_pressed_time) < BUNNY_WINDOW &&
            elapsed_time - new_jump_pressed_time < BUNNY_WINDOW
        )

    bunny_hop_triggered := on_surface && pls.spin_state.spinning &&
                           (pls.hops_remaining > 0 || INFINITE_HOP)

    should_jump := (is.z_pressed && pls.jump_enabled) || bunny_hop_triggered || small_hop_triggered

    ground_jump_coyote_time_active := elapsed_time - cts.left_ground < COYOTE_TIME
    slope_jump_coyote_time_active  := elapsed_time - cts.left_slope  < COYOTE_TIME
    wall_jump_coyote_time_active   := elapsed_time - cts.left_wall   < COYOTE_TIME

    ground_jump_triggered := should_jump && (cts.state == .ON_GROUND || ground_jump_coyote_time_active)
    slope_jump_triggered  := should_jump && (cts.state == .ON_SLOPE  || slope_jump_coyote_time_active) 
    wall_jump_triggered   := should_jump && (cts.state == .ON_WALL   || wall_jump_coyote_time_active)

    jump_triggered := ground_jump_triggered || slope_jump_triggered || wall_jump_triggered

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

    is_hurt := elapsed_time < pls.hurt_t + DAMAGE_LEN
    in_slide_zone := len(szs.intersected) > 0
    sent_to_checkpoint := pls.position.y < -100

    return {
        input_x, input_z, input_dir, got_dir_input, got_fwd_input, on_surface,
        normalized_contact_ray, small_hop_triggered, bunny_hop_triggered,
        ground_jump_triggered, slope_jump_triggered, wall_jump_triggered,
        jump_triggered, grounded, is_hurt, in_slide_zone, right_vec, fwd_vec,
        move_spd, sent_to_checkpoint
    }
}

pre_collision_velocity_update :: proc(
    velocity: [3]f32,
    is: Input_State,
    pls: Player_State,
    attrs: Player_State_Attributes,
    elapsed_time: f32,
    delta_time: f32,
    new_wall_detach_held_t: f32
) -> (new_velocity: [3]f32) {
    using attrs
    new_velocity = velocity
    cts := pls.contact_state

    // apply directional input to velocity
    // -------------------------------------------
    if !is_hurt {
        if is.left_pressed {
            new_velocity -= move_spd * delta_time * right_vec
        }
        if is.right_pressed {
            new_velocity += move_spd * delta_time * right_vec
        }
        if is.up_pressed {
            new_velocity += move_spd * delta_time * fwd_vec
        }
        if is.down_pressed {
            new_velocity -= move_spd * delta_time * fwd_vec
        }
        if is.hor_axis != 0 {
            new_velocity += move_spd * delta_time * is.hor_axis * right_vec
        }
        if is.vert_axis != 0 {
            new_velocity += move_spd * delta_time * is.vert_axis * fwd_vec
        }
    }

    // clamp velocity to max speed
    // -------------------------------------------
    if got_fwd_input {
        new_velocity.xz = math.lerp(
            new_velocity.xz,
            la.clamp_length(new_velocity.xz, MAX_PLAYER_SPEED),
            f32(0.01)
        )
    } else {
        new_velocity.xz = math.lerp(
            new_velocity.xz,
            la.clamp_length(new_velocity.xz, FAST_CUTOFF),
            f32(0.1)
        )
    }
    new_velocity.y = math.clamp(new_velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply friction to velocity 
    // -------------------------------------------
    // if cts.state == .ON_GROUND && !got_dir_input {
    if !got_dir_input {
        if la.length(pls.velocity.xz) > FAST_CUTOFF {
            new_velocity *= math.pow(FAST_FRICTION, delta_time)
        } else if !on_surface {
            new_velocity *= math.pow(IDLE_FRICTION, delta_time)
        }
    } else if on_surface {
        new_velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity to velocity
    // -------------------------------------------
    if cts.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        grav_force := GRAV
        if cts.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if cts.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if cts.state == .ON_WALL || cts.state == .ON_SLOPE {
            down -= la.dot(normalized_contact_ray, down) * normalized_contact_ray
        }
        new_velocity += down * grav_force * delta_time
    }

    // apply wall stick to velocity
    // -------------------------------------------
    if cts.state == .ON_WALL && new_wall_detach_held_t < WALL_DETACH_LEN {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    } 

    // apply dash to velocity
    // -------------------------------------------
    if pls.dash_state.dashing {
        new_velocity = pls.dash_state.dash_dir * pls.dash_state.dash_spd
    }

    // apply slide to velocity
    // -------------------------------------------
    if pls.slide_state.sliding {
        new_velocity = pls.slide_state.slide_dir * (in_slide_zone ? SLIDE_SPD * 2 : SLIDE_SPD) 
    }

    // apply slope to velocity
    // -------------------------------------------
    if cts.state == .ON_GROUND || cts.state == .ON_SLOPE {
        new_velocity -= la.dot(new_velocity, normalized_contact_ray) * normalized_contact_ray
    }

    // apply jump to velocity
    // -------------------------------------------
    if ground_jump_triggered {
        new_velocity.y = P_JUMP_SPEED
    } else if slope_jump_triggered {
        new_velocity += -normalized_contact_ray * SLOPE_JUMP_FORCE * (small_hop_triggered ? 0.25 : 1.0)
        new_velocity.y = SLOPE_V_JUMP_FORCE
    } else if wall_jump_triggered {
        new_velocity.y = P_JUMP_SPEED
        new_velocity += -normalized_contact_ray * WALL_JUMP_FORCE 
    }
    if bunny_hop_triggered {
        if ground_jump_triggered {
            new_velocity.y = GROUND_BUNNY_V_SPEED - (1.0 - pls.spin_state.spin_amt) * BUNNY_SPIN_VARIANCE

        }
        new_velocity.xz += la.normalize0(new_velocity.xz) * GROUND_BUNNY_H_SPEED
    } else if small_hop_triggered && ground_jump_triggered {
        new_velocity.y = SMALL_HOP_V_SPEED
    }

    // apply restart to velocity
    // -------------------------------------------
    if is.r_pressed  {
        new_velocity = [3]f32{0, 0, 0}
    }

    // apply checkpoint to velocity
    // -------------------------------------------
    if sent_to_checkpoint {
        new_velocity = [3]f32{0, 0, -40}
    }

    new_cts := pls.contact_state

    return new_velocity
}
