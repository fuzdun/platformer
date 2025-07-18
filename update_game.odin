package main

import la "core:math/linalg"
import "core:math"


game_update :: proc(lgs: Level_Geometry_State, is: Input_State, pls: ^Player_State, phs: Physics_State, cs: ^Camera_State, ts: ^Time_State, elapsed_time: f32, delta_time: f32) {

    // ====================================
    // HANDLE INPUT, UPDATE PLAYER VELOCITY
    // ====================================
    // update trail
    ring_buffer_push(&pls.trail, [3]f32 {f32(pls.position.x), f32(pls.position.y), f32(pls.position.z)})
    pls.prev_trail_sample = pls.trail_sample
    pls.trail_sample = {ring_buffer_at(pls.trail, -4), ring_buffer_at(pls.trail, -8), ring_buffer_at(pls.trail, -12)}

    move_spd := P_ACCEL
    if pls.state == .ON_SLOPE {
        move_spd = SLOPE_SPEED 
    } else if pls.state == .IN_AIR {
        move_spd = AIR_SPEED
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

    // adjust velocity along air or ground axes
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

    // register jump button pressed
    if is.z_pressed {
        pls.jump_pressed_time = f32(elapsed_time)
    }

    // clamp xz velocity
    clamped_xz := la.clamp_length(pls.velocity.xz, MAX_PLAYER_SPEED)
    pls.velocity.xz = math.lerp(pls.velocity.xz, clamped_xz, f32(0.05))
    pls.velocity.y = math.clamp(pls.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)

    // apply ground friction
    if pls.state == .ON_GROUND && !got_dir_input {
        pls.velocity *= math.pow(GROUND_FRICTION, delta_time)
    }

    // apply gravity
    if pls.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(pls.contact_ray)
        grav_force := GRAV
        if pls.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if pls.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if pls.state == .ON_WALL || pls.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        pls.velocity += down * grav_force * delta_time
    }

    // bunny hop
    can_bunny_hop := f32(elapsed_time) - pls.last_dash > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := pls.state != .IN_AIR && math.abs(pls.touch_time - pls.jump_pressed_time) < BUNNY_WINDOW
    if got_bunny_hop_input && can_bunny_hop {
        pls.can_press_dash = true
        pls.bunny_hop_y = pls.position.y
        pls.state = .IN_AIR
        pls.velocity.y = GROUND_BUNNY_V_SPEED
        if la.length(pls.velocity.xz) > MIN_BUNNY_XZ_VEL {
            pls.velocity.xz += la.normalize(pls.velocity.xz) * GROUND_BUNNY_H_SPEED
        }
        pls.crunch_pt = pls.position - {0, 0, 0.5}
        pls.crunch_time = f32(elapsed_time)
        pls.last_dash = f32(elapsed_time)
    }

    // check for jump
    pressed_jump := is.z_pressed && pls.can_press_jump
    ground_jumped := pressed_jump && (pls.state == .ON_GROUND || (f32(elapsed_time) - pls.left_ground < COYOTE_TIME))
    slope_jumped := pressed_jump && (pls.state == .ON_SLOPE || (f32(elapsed_time) - pls.left_slope < COYOTE_TIME))
    wall_jumped := pressed_jump && (pls.state == .ON_WALL || (f32(elapsed_time) - pls.left_wall < COYOTE_TIME))

    // handle normal jump
    if ground_jumped {
        pls.velocity.y = P_JUMP_SPEED
        pls.state = .IN_AIR

    // handle slope jump
    } else if slope_jumped {
        pls.velocity += -la.normalize(pls.contact_ray) * SLOPE_JUMP_FORCE
        pls.velocity.y = SLOPE_V_JUMP_FORCE
        pls.state = .IN_AIR

    // handle wall jump
    } else if wall_jumped {
        pls.velocity.y = P_JUMP_SPEED
        pls.velocity += -pls.contact_ray * WALL_JUMP_FORCE 
        pls.state = .IN_AIR
    }

    // set target particle displacement on jump
    if ground_jumped || slope_jumped || wall_jumped {
        pls.can_press_jump = false
        pls.tgt_particle_displacement = pls.velocity
    }

    // lerp current particle displacement toward target particle displacement
    pls.particle_displacement = la.lerp(pls.particle_displacement, pls.tgt_particle_displacement, PARTICLE_DISPLACEMENT_LERP)
    if !(pls.state == .ON_GROUND) {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, pls.velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        pls.tgt_particle_displacement = la.lerp(pls.tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }

    // start dash 
    pressed_dash := is.x_pressed && pls.can_press_dash
    if pressed_dash && pls.velocity != 0 {
        pls.can_press_dash = false
        pls.dashing = true
        pls.dash_start_pos = pls.position
        dash_input := input_dir == 0 ? la.normalize0(pls.velocity.xz) : input_dir
        pls.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
        pls.dash_end_pos = pls.position + DASH_DIST * pls.dash_dir
        pls.dash_time = f32(elapsed_time)
    }

    //end dash
    hit_surface := pls.state == .ON_WALL || grounded
    dash_expired := f32(elapsed_time) > pls.dash_time + DASH_LEN
    if pls.dashing && (hit_surface || dash_expired){
        pls.dash_end_time = f32(elapsed_time)
        pls.dashing = false
        pls.velocity = la.normalize(pls.dash_end_pos - pls.dash_start_pos) * DASH_SPD
        pls.position = pls.dash_end_pos
    }
     
    // during dash
    if pls.dashing {
        pls.velocity = 0
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        pls.position = pls.dash_start_pos; //pls.dash_start_pos + dash_delta * dash_t
    }

    // bunny hop time dilation
    if pls.state != .ON_GROUND && f32(elapsed_time) - pls.crunch_time < 1000 {
        if pls.position.y > pls.bunny_hop_y {
            fact := abs(pls.velocity.y) / GROUND_BUNNY_V_SPEED
            ts.time_mult = clamp(fact * fact * 4.5, 1.15, 1.5)
        } else {
            ts.time_mult = f32(math.lerp(ts.time_mult, 1, f32(0.05)))
        }

    } else {
        ts.time_mult = f32(math.lerp(ts.time_mult, 1, f32(0.05)))
    }

    // debounce jump/dash input
    if !pls.can_press_jump {
        pls.can_press_jump = !is.z_pressed && grounded || pls.state == .ON_WALL
    }
    if !pls.can_press_dash {
        pls.can_press_dash = !is.x_pressed && pls.state == .ON_GROUND
    }

    // lerp spike compression
    if pls.state == .ON_GROUND {
        pls.spike_compression = math.lerp(pls.spike_compression, 0.35, 0.15) 
    } else {
        pls.spike_compression = math.lerp(pls.spike_compression, 1.00, 0.15) 
    }

    // handle reset level
    if is.r_pressed {
        pls.position = INIT_PLAYER_POS
        pls.velocity = [3]f32 {0, 0, 0}
    }

    pls.prev_position = pls.position


    // ========================================
    // APPLY PLAYER VELOCITY, HANDLE COLLISIONS
    // ========================================
    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    velocity_normal := la.normalize(pls.velocity)
    collisions := make([dynamic]Collision); defer delete(collisions)
    got_contact := false

    // inline func ========
    get_collisions :: proc(
        lgs: Level_Geometry_State,
        pls: Player_State,
        phs: Physics_State,
        et: f32,
        dt: f32,
        collisions: ^[dynamic]Collision,
        got_contact: ^bool
    ) {
        clear(collisions)
        got_contact^ = false
        filter: bit_set[Level_Geometry_Component_Name; u64] = { .Collider, .Transform }
        player_velocity := pls.velocity * dt
        player_velocity_len := la.length(player_velocity)
        player_velocity_normal := la.normalize(player_velocity)
        ppos_end := pls.position + player_velocity

        transformed_coll_vertices := phs.static_collider_vertices
        tv_offset := 0

        for lg, id in lgs.entities {
            coll := phs.level_colliders[lg.collider] 
            if filter <= lg.attributes {
                if sphere_aabb_collision(pls.position, PLAYER_SPHERE_SQ_RADIUS, lg.aabb) {
                    vertices := transformed_coll_vertices[tv_offset:tv_offset + len(coll.vertices)] 
                    l := len(coll.indices)
                    for i := 0; i <= l - 3; i += 3 {
                        t0 := vertices[coll.indices[i]]
                        t1 := vertices[coll.indices[i+1]]
                        t2 := vertices[coll.indices[i+2]]
                        did_collide, t, normal, contact := player_lg_collision(
                            pls.position,
                            PLAYER_SPHERE_RADIUS,
                            t0, t1, t2,
                            player_velocity,
                            player_velocity_len,
                            player_velocity_normal,
                            ppos_end,
                            pls.contact_ray,
                            GROUNDED_RADIUS2
                        )
                        if did_collide {
                            append(collisions, Collision{id, normal, t})
                        }
                        got_contact^ = got_contact^ || contact
                    }
                }
            }         
            tv_offset += len(coll.vertices)
        }
        return
    }
    
    pls.anim_angle = math.lerp(pls.anim_angle, math.atan2(pls.velocity.x, -pls.velocity.z), f32(0.1))
    // end func ==========

    // inline func ==============
    update_contact_state :: proc(
        pls: ^Player_State,
        collisions: []Collision,
        et: f32,
        got_contact: bool
    ) {
        // handle lost surface contact
        if (pls.state == .ON_GROUND || pls.state == .ON_WALL || pls.state == .ON_SLOPE) && !got_contact {
            pls.state = .IN_AIR
        }

        // update coyote time
        if pls.state == .ON_GROUND {
            pls.left_ground = et
        }
        if pls.state == .ON_SLOPE {
            pls.left_slope = et
        }
        if pls.state == .ON_WALL {
            pls.left_wall = et
        }

        // get most horizontal collided surface
        best_plane_normal: [3]f32 = {100, 100, 100}
        most_horizontal_coll: Collision = {} 
        for coll in collisions {
            if abs(coll.normal.y) < best_plane_normal.y {
                best_plane_normal = coll.normal
                most_horizontal_coll = coll 
            }
        }

        if best_plane_normal.y < 100.0 {
            old_state := pls.state
            ground_x := [3]f32{1, 0, 0}
            ground_z := [3]f32{0, 0, -1}
            pls.contact_ray = -best_plane_normal * GROUND_RAY_LEN
            pls.bunny_hop_y = max(f32)
            // collided with ground
            if best_plane_normal.y >= 0.85{
                pls.state = .ON_GROUND
            // collided with slope
            } else if .2 <= best_plane_normal.y && best_plane_normal.y < .85 {
                pls.state = .ON_SLOPE
            // collided with wall
            } else if best_plane_normal.y < .2 && pls.state != .ON_GROUND {
                pls.state = .ON_WALL
            }
            // align movement vectors to ground surface
            if pls.state == .ON_GROUND || pls.state == .ON_SLOPE {
                pls.ground_x = la.normalize(ground_x - la.dot(ground_x, best_plane_normal) * best_plane_normal)
                pls.ground_z = la.normalize(ground_z - la.dot(ground_z, best_plane_normal) * best_plane_normal)
            }
            if pls.state != old_state {
                pls.touch_time = et
            }
        }
    }
    // end func ==========

    get_collisions(lgs, pls^, phs, elapsed_time, delta_time, &collisions, &got_contact)
    update_contact_state(pls, collisions[:], elapsed_time, got_contact)

    if remaining_vel > 0 {
        loops := 0
        for len(collisions) > 0 && loops < 10 {
            loops += 1
            earliest_coll_t: f32 = 1.1
            earliest_coll_idx := -1
            for coll, idx in collisions {
                if coll.t < earliest_coll_t {
                    earliest_coll_idx = idx
                    earliest_coll_t = coll.t
                }
            }
            earliest_coll := collisions[earliest_coll_idx]
            pls.position += (remaining_vel * (earliest_coll_t) - .01) * velocity_normal
            remaining_vel *= 1.0 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            pls.velocity = (velocity_normal * remaining_vel) / delta_time

            get_collisions(lgs, pls^, phs, elapsed_time, delta_time, &collisions, &got_contact)
            update_contact_state(pls, collisions[:], elapsed_time, got_contact)
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }

    // update camera
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    ppos := pls.position
    if pls.dashing {
        dash_t := (f32(elapsed_time) - pls.dash_time) / DASH_LEN
        dash_delta := pls.dash_end_pos - pls.dash_start_pos
        ppos = pls.dash_start_pos + dash_delta * dash_t
    }
    tgt_y := ppos.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := ppos.z + CAMERA_PLAYER_Z_OFFSET
    tgt_x := ppos.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(CAMERA_POS_LERP))
    // cs.position = {0, 100, 30}
    cs.target.x = math.lerp(cs.target.x, ppos.x, f32(CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, ppos.y, f32(CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, ppos.z, f32(CAMERA_Z_LERP))
}

