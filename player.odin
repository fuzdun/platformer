package main

import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:fmt"

import st "state"
import const "constants"

update_player_velocity :: proc(gs: ^st.Game_State, pls: ^st.Player_State, elapsed_time: f64, delta_time: f32) {
    is := &gs.input_state

    // update trail
    st.ring_buffer_push(&pls.trail, [3]f32 {f32(pls.position.x), f32(pls.position.y), f32(pls.position.z)})
    pls.prev_trail_sample = pls.trail_sample
    pls.trail_sample = {st.ring_buffer_at(pls.trail, -4), st.ring_buffer_at(pls.trail, -8), st.ring_buffer_at(pls.trail, -12)}

    move_spd := const.P_ACCEL
    if pls.state == .ON_SLOPE {
        move_spd = const.SLOPE_SPEED 
    } else if pls.state == .IN_AIR {
        move_spd = const.AIR_SPEED
    }

    // process directional input
    input_x: f32 = 0.0
    input_z: f32 = 0.0
    if is.left_pressed do input_x -= 1
    if is.right_pressed do input_x += 1
    if is.up_pressed do input_z -= 1
    if is.down_pressed do input_z += 1
    input_dir := la.normalize0([2]f32{input_x, input_z})
    if is.hor_axis !=0 || is.vert_axis != 0 {
        input_dir = la.normalize0([2]f32{is.hor_axis, -is.vert_axis})
    }
    got_dir_input := is.a_pressed || is.s_pressed || is.d_pressed || is.w_pressed || is.hor_axis != 0 || is.vert_axis != 0

    // move player through air or along ground axes
    grounded := pls.state == .ON_GROUND || pls.state == .ON_SLOPE
    right_vec := grounded ? pls.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? pls.ground_z : [3]f32{0, 0, -1}
    if is.left_pressed {
       pls.velocity -= move_spd * delta_time * right_vec
    }
    if is.right_pressed {
        pls.velocity += move_spd * delta_time * right_vec
    }
    if is.up_pressed {
        pls.velocity += move_spd * delta_time * fwd_vec
    }
    if is.down_pressed {
        pls.velocity -= move_spd * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        pls.velocity += move_spd * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        pls.velocity += move_spd * delta_time * is.vert_axis * fwd_vec
    }

    // register jump pressed
    if is.z_pressed {
        pls.jump_pressed_time = f32(elapsed_time)
    }

    // clamp xz velocity
    clamped_xz := la.clamp_length(pls.velocity.xz, const.MAX_PLAYER_SPEED)
    pls.velocity.xz = math.lerp(pls.velocity.xz, clamped_xz, f32(0.05))
    pls.velocity.y = math.clamp(pls.velocity.y, -const.MAX_FALL_SPEED, const.MAX_FALL_SPEED)

    // apply ground friction
    if pls.state == .ON_GROUND && !got_dir_input {
        pls.velocity *= math.pow(const.GROUND_FRICTION, delta_time)
    }

    // apply gravity
    if pls.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(pls.contact_ray)
        grav_force := const.GRAV
        if pls.state == .ON_SLOPE {
            grav_force = const.SLOPE_GRAV
        }
        if pls.state == .ON_WALL {
            grav_force = const.WALL_GRAV
        }
        if pls.state == .ON_WALL || pls.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        pls.velocity += down * grav_force * delta_time
    }

    // bunny hop
    can_bunny_hop := f32(elapsed_time) - pls.last_dash > const.BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := pls.state != .IN_AIR && math.abs(pls.touch_time - pls.jump_pressed_time) < const.BUNNY_WINDOW
    if got_bunny_hop_input && can_bunny_hop {
        pls.can_press_dash = true
        pls.bunny_hop_y = pls.position.y
        pls.state = .IN_AIR
        pls.velocity.y = const.GROUND_BUNNY_V_SPEED
        if la.length(pls.velocity.xz) > const.MIN_BUNNY_XZ_VEL {
            pls.velocity.xz += la.normalize(pls.velocity.xz) * const.GROUND_BUNNY_H_SPEED
        }
        pls.crunch_pt = pls.position - {0, 0, 0.5}
        pls.crunch_time = f32(elapsed_time)
        pls.last_dash = f32(elapsed_time)
    }

    // jumps
    pressed_jump := is.z_pressed && pls.can_press_jump
    ground_jumped := pressed_jump && (pls.state == .ON_GROUND || (f32(elapsed_time) - pls.left_ground < const.COYOTE_TIME))
    slope_jumped := pressed_jump && (pls.state == .ON_SLOPE || (f32(elapsed_time) - pls.left_slope < const.COYOTE_TIME))
    wall_jumped := pressed_jump && (pls.state == .ON_WALL || (f32(elapsed_time) - pls.left_wall < const.COYOTE_TIME))


    // normal jump
    if ground_jumped {
        pls.velocity.y = const.P_JUMP_SPEED
        pls.state = .IN_AIR

    // slope jump
    } else if slope_jumped {
        pls.velocity += -la.normalize(pls.contact_ray) * const.SLOPE_JUMP_FORCE
        pls.velocity.y = const.SLOPE_V_JUMP_FORCE
        pls.state = .IN_AIR

    // wall jump
    } else if wall_jumped {
        pls.velocity.y = const.P_JUMP_SPEED
        pls.velocity += -pls.contact_ray * const.WALL_JUMP_FORCE 
        pls.state = .IN_AIR
    }

    // set particle displacement on jump
    if ground_jumped || slope_jumped || wall_jumped {
        pls.can_press_jump = false
        pls.tgt_particle_displacement = pls.velocity
    }

    // lerp particle displacement toward target
    pls.particle_displacement = la.lerp(pls.particle_displacement, pls.tgt_particle_displacement, const.PARTICLE_DISPLACEMENT_LERP)
    pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, pls.velocity, const.TGT_PARTICLE_DISPLACEMENT_LERP)

    // dash 
    pressed_dash := is.x_pressed && pls.can_press_dash
    if pressed_dash && pls.velocity != 0 {
        pls.can_press_dash = false
        pls.dashing = true
        pls.dash_start_pos = pls.position
        dash_input := input_dir == 0 ? la.normalize0(pls.velocity.xz) : input_dir
        pls.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        pls.dash_end_pos = pls.position + const.DASH_DIST * pls.dash_dir
        pls.dash_time = f32(elapsed_time)
    }

    //end dash
    hit_surface := pls.state == .ON_WALL || grounded
    dash_expired := f32(elapsed_time) > pls.dash_time + const.DASH_LEN
    if pls.dashing && (hit_surface || dash_expired){
        pls.dash_end_time = f32(elapsed_time)
        pls.dashing = false
        pls.velocity = la.normalize(pls.dash_end_pos - pls.dash_start_pos) * const.DASH_SPD
        pls.position = pls.dash_end_pos
    }
     
    // dashing
    if pls.dashing {
        pls.velocity = 0
        dash_t := (f32(elapsed_time) - pls.dash_time) / const.DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        pls.position = pls.dash_start_pos; //pls.dash_start_pos + dash_delta * dash_t
    }

    // bunny hop time dilation
    if pls.state != .ON_GROUND && f32(elapsed_time) - pls.crunch_time < 1000 {
        if pls.position.y > pls.bunny_hop_y {
            fact := abs(pls.velocity.y) / const.GROUND_BUNNY_V_SPEED
            gs.time_mult = clamp(fact * fact * 4.5, 1.15, 1.5)
        } else {
            gs.time_mult = f32(math.lerp(gs.time_mult, 1, f32(0.05)))
        }

    } else {
        gs.time_mult = f32(math.lerp(gs.time_mult, 1, f32(0.05)))
    }

    // debounce jump/dash input
    if !pls.can_press_jump {
        pls.can_press_jump = !is.z_pressed && grounded || pls.state == .ON_WALL
    }
    if !pls.can_press_dash {
        pls.can_press_dash = !is.x_pressed && pls.state == .ON_GROUND
    }

    // handle reset
    if is.r_pressed {
        pls.position = const.INIT_PLAYER_POS
        pls.velocity = [3]f32 {0, 0, 0}
    }

}

move_player :: proc(gs: ^st.Game_State, pls: ^st.Player_State, phs: ^st.Physics_State, elapsed_time: f32, delta_time: f32) {
    //pls := &gs.player_state
    pls.prev_position = pls.position

    // if pls.dashing {
    //     pls.velocity = pls.dash_vel
    // }

    init_velocity_len := la.length(pls.velocity)

    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)

    get_collisions(gs, pls, phs, delta_time, elapsed_time)
    if remaining_vel > 0 {
        loops := 0
        for len(phs.collisions) > 0 && loops < 10 {
            loops += 1
            earliest_coll_t: f32 = 1.1
            earliest_coll_idx := -1
            for coll, idx in phs.collisions {
                if coll.t < earliest_coll_t {
                    earliest_coll_idx = idx
                    earliest_coll_t = coll.t
                }
            }
            earliest_coll := phs.collisions[earliest_coll_idx]
            move_amt := (remaining_vel * (earliest_coll_t) - .01) * velocity_normal
            pls.position += move_amt
            remaining_vel *= 1.0 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            pls.velocity = (velocity_normal * (remaining_vel)) / delta_time
            get_collisions(gs, pls, phs, delta_time, elapsed_time)
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }
}

interpolated_player_pos :: proc(ps: st.Player_State, t: f32) -> [3]f32 {
    return math.lerp(ps.prev_position, ps.position, t) 
}

interpolated_trail :: proc(ps: st.Player_State, t: f32) -> [3]glm.vec3 {
    return math.lerp(ps.prev_trail_sample, ps.trail_sample, t)
}

interpolated_player_matrix :: proc(ps: st.Player_State, t: f32) -> matrix[4, 4]f32 {
    i_pos := math.lerp(ps.prev_position, ps.position, t) 
    rot := const.I_MAT
    offset := glm.mat4Translate({f32(i_pos.x), f32(i_pos.y), f32(i_pos.z)})
    return rot * offset
}

