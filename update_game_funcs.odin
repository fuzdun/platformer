package main

import la "core:math/linalg"
import "core:math"
import "core:fmt"


updated_spike_compression :: proc(spike_compression: f64, state: Player_States) -> f64 {
    if state == .ON_GROUND {
        return math.lerp(spike_compression, MIN_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
    } 
    return math.lerp(spike_compression, MAX_SPIKE_COMPRESSION, SPIKE_COMPRESSION_LERP)
}

updated_trail_buffer :: proc(player_position: [3]f32, trail: RingBuffer(TRAIL_SIZE, [3]f32)) -> RingBuffer(TRAIL_SIZE, [3]f32) {
    new_trail := ring_buffer_copy(trail)
    ring_buffer_push(&new_trail, [3]f32 {f32(player_position.x), f32(player_position.y), f32(player_position.z)})
    return new_trail
}

updated_trail_sample :: proc(trail: RingBuffer(TRAIL_SIZE, [3]f32)) -> [3][3]f32 {
    return {ring_buffer_at(trail, -4), ring_buffer_at(trail, -8), ring_buffer_at(trail, -12)}
}

updated_jump_pressed_time :: proc(jump_pressed_time: f32, is: Input_State, jump_held: bool, elapsed_time: f32) -> f32 {
    return (is.z_pressed && !jump_held) ? elapsed_time : jump_pressed_time
}

updated_crunch_pt :: proc(player_position: [3]f32, crunch_pt: [3]f32, did_bunny_hop: bool) -> [3]f32 {
    return did_bunny_hop ? player_position : crunch_pt
}

updated_can_press_dash :: proc(dash_hop_debouce_t: f32, did_dash: bool, can_press_dash: bool, contact_state: Contact_State, is: Input_State, jump_pressed_time: f32, elapsed_time: f32) -> bool {
    can_bunny_hop := f32(elapsed_time) - dash_hop_debouce_t > BUNNY_DASH_DEBOUNCE
    got_bunny_hop_input := contact_state.state != .IN_AIR && math.abs(contact_state.touch_time - jump_pressed_time) < BUNNY_WINDOW
    pressed_dash := is.x_pressed && can_press_dash
    if got_bunny_hop_input && can_bunny_hop {
        return true
    } 
    if did_dash {
        return false
    }
    if !can_press_dash {
        return !is.x_pressed && contact_state.state == .ON_GROUND
    } 
    return true
}

updated_dashing :: proc(dashing: bool, did_dash: bool, state: Player_States, dash_time: f32, elapsed_time: f32) -> bool {
  if did_dash {
    return true
  }

  if state == .ON_WALL || state == .ON_SLOPE || state == .ON_GROUND || f32(elapsed_time) > dash_time + DASH_LEN {
    return false 
  }
  return dashing
}


apply_dash_to_position :: proc(position: [3]f32, dash_start_pos: [3]f32, dash_end_pos: [3]f32, dashing: bool, dash_time: f32, elapsed_time: f32) -> [3]f32 {
  if dashing {
    dash_t := (f32(elapsed_time) - dash_time) / DASH_LEN
    dash_delta := dash_end_pos - dash_start_pos
    return dash_start_pos + dash_delta * dash_t
  }
  return position
}

apply_restart_to_position :: proc(is: Input_State, position: [3]f32) -> [3]f32 {
  return is.r_pressed ? INIT_PLAYER_POS : position
}


apply_restart_to_lgs :: proc(is: Input_State, lgs: Level_Geometry_Soa) -> Level_Geometry_Soa {
  lgs := dynamic_soa_copy(lgs)
  if is.r_pressed {
    for &lg in lgs {
      lg.crack_time = 0
    }
  }
  return lgs
}

apply_dash_to_velocity :: proc(pls: Player_State, velocity: [3]f32, elapsed_time: f32) -> [3]f32 {
  velocity := velocity
  state := pls.contact_state.state
  dash_expired := f32(elapsed_time) > pls.dash_state.dash_time + DASH_LEN
  hit_surface := state == .ON_WALL || state == .ON_GROUND || state == .ON_WALL
  if pls.dashing {
    if hit_surface || dash_expired {
      velocity = la.normalize(pls.dash_state.dash_end_pos - pls.dash_state.dash_start_pos) * DASH_SPD
    } else {
      velocity = 0
    }

  } 
  return velocity
}

apply_restart_to_velocity :: proc(is: Input_State, velocity: [3]f32) -> [3]f32 {
  return is.r_pressed ? {0, 0, 0} : velocity
}


updated_dash_state :: proc(pls: Player_State, did_dash: bool, input_dir: [2]f32, elapsed_time: f32) -> Dash_State {
  ds := pls.dash_state
  if did_dash {
    ds.dash_start_pos = pls.position
    dash_input := input_dir == 0 ? la.normalize0(pls.velocity.xz) : input_dir
    ds.dash_dir = [3]f32{dash_input.x, 0, dash_input.y}
    ds.dash_end_pos = pls.position + DASH_DIST * ds.dash_dir
    ds.dash_time = f32(elapsed_time)
  }
  return ds
}

updated_crunch_time :: proc(did_bunny_hop: bool, crunch_time: f32, elapsed_time: f32) -> f32 {
    return did_bunny_hop ? elapsed_time : crunch_time 
}

apply_directional_input_to_velocity :: proc(contact_state: Contact_State, is: Input_State, velocity: [3]f32, move_spd: f32, delta_time: f32) -> [3]f32 {
    velocity := velocity
    grounded := contact_state.state == .ON_GROUND || contact_state.state == .ON_SLOPE
    right_vec := grounded ? contact_state.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? contact_state.ground_z : [3]f32{0, 0, -1}
    if is.left_pressed {
        velocity -= move_spd * delta_time * right_vec
    }
    if is.right_pressed {
        velocity += move_spd * delta_time * right_vec
    }
    if is.up_pressed {
        velocity += move_spd * delta_time * fwd_vec
    }
    if is.down_pressed {
        velocity -= move_spd * delta_time * fwd_vec
    }
    if is.hor_axis != 0 {
        velocity += move_spd * delta_time * is.hor_axis * right_vec
    }
    if is.vert_axis != 0 {
        velocity += move_spd * delta_time * is.vert_axis * fwd_vec
    }
    return velocity
}

clamp_horizontal_velocity_to_max_speed :: proc(velocity: [3]f32) -> [3]f32 {
    velocity := velocity
    clamped_xz := la.clamp_length(velocity.xz, MAX_PLAYER_SPEED)
    velocity.xz = math.lerp(velocity.xz, clamped_xz, f32(0.05))
    velocity.y = math.clamp(velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)
    return velocity
}

apply_friction_to_velocity :: proc(state: Player_States, velocity: [3]f32, got_dir_input: bool, delta_time: f32) -> [3]f32 {
    return (state == .ON_GROUND && !got_dir_input) ? velocity * math.pow(GROUND_FRICTION, delta_time) : velocity
}

apply_gravity_to_velocity :: proc(velocity: [3]f32, contact_state: Contact_State, delta_time: f32) -> [3]f32 {
    if contact_state.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(contact_state.contact_ray)
        grav_force := GRAV
        if contact_state.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if contact_state.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if contact_state.state == .ON_WALL || contact_state.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        return velocity + down * grav_force * delta_time
    }
    return velocity
}

apply_jumps_to_velocity :: proc(velocity: [3]f32, did_bunny_hop: bool, ground_jumped: bool, slope_jumped: bool, wall_jumped: bool, contact_ray: [3]f32) -> [3]f32 {
    velocity := velocity
    if did_bunny_hop {
        velocity.y = GROUND_BUNNY_V_SPEED
        if la.length(velocity.xz) > MIN_BUNNY_XZ_VEL {
            velocity.xz += la.normalize(velocity.xz) * GROUND_BUNNY_H_SPEED
        }
    } else if ground_jumped {
        velocity.y = P_JUMP_SPEED
    } else if slope_jumped {
        velocity += -la.normalize(contact_ray) * SLOPE_JUMP_FORCE
        velocity.y = SLOPE_V_JUMP_FORCE
    } else if wall_jumped {
        velocity.y = P_JUMP_SPEED
        velocity += -contact_ray * WALL_JUMP_FORCE 
    }
    return velocity
}

updated_dash_hop_debounce_t :: proc(dash_hop_debouce_t: f32, did_bunny_hop: bool, elapsed_time: f32) -> f32 {
    return did_bunny_hop ? elapsed_time : dash_hop_debouce_t 
}

updated_screen_crunch_pt :: proc(screen_crunch_pt: [2]f32, did_bunny_hop: bool, cs: Camera_State, new_crunch_pt: [3]f32) -> [2]f32 {
    if did_bunny_hop {
        proj_mat :=  construct_camera_matrix(cs)
        proj_ppos := la.matrix_mul_vector(proj_mat, [4]f32{new_crunch_pt.x, new_crunch_pt.y, new_crunch_pt.z, 1})
        return ((proj_ppos / proj_ppos.w) / 2.0 + 0.5).xy
    } 
    return screen_crunch_pt
}

apply_velocity :: proc(
    contact_state: Contact_State,
    position: [3]f32,
    velocity: [3]f32,
    entities: #soa[]Level_Geometry, 
    level_colliders: [SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
    elapsed_time: f32,
    delta_time: f32
) -> (
    new_contact_state: Contact_State,
    new_position: [3]f32,
    new_velocity: [3]f32,
    collision_ids: map[int]struct{}
) {
    new_position = position
    new_velocity = velocity
    collision_ids = make(map[int]struct{})
    collisions, got_contact := get_collisions(entities[:], position, velocity, contact_state.contact_ray, level_colliders, static_collider_vertices, elapsed_time, delta_time);
    defer delete(collisions)
    for collision in collisions {
        collision_ids[collision.id] = {}
    }
    new_contact_state = update_player_contact_state( contact_state, collisions[:], got_contact, elapsed_time)
    init_velocity_len := la.length(velocity)
    remaining_vel := init_velocity_len * delta_time
    if remaining_vel > 0 {
        velocity_normal := la.normalize(velocity)
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
            new_position += (remaining_vel * (earliest_coll_t) - .01) * velocity_normal
            remaining_vel *= 1.0 - earliest_coll_t
            velocity_normal -= la.dot(velocity_normal, earliest_coll.normal) * earliest_coll.normal
            new_velocity = (velocity_normal * remaining_vel) / delta_time
            delete(collisions)
            collisions, got_contact = get_collisions(entities, new_position, new_velocity, contact_state.contact_ray, level_colliders, static_collider_vertices, elapsed_time, delta_time)
            for collision in collisions {
                collision_ids[collision.id] = {}
            }
            new_contact_state = update_player_contact_state(
                new_contact_state,
                collisions[:],
                got_contact,
                elapsed_time)
        }
        new_position += velocity_normal * remaining_vel
        new_velocity = velocity_normal * init_velocity_len
    }
    return
}

get_collisions :: proc(
    entities: #soa[]Level_Geometry,
    position: [3]f32,
    velocity: [3]f32,
    contact_ray: [3]f32,
    level_colliders: [SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
    et: f32,
    dt: f32,
) -> (
    collisions: [dynamic]Collision,
    got_contact: bool
) {
    collisions = make([dynamic]Collision)
    got_contact = false
    player_velocity := velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := position + player_velocity

    transformed_coll_vertices := static_collider_vertices
    tv_offset := 0

    filter: Level_Geometry_Attributes = { .Collider, .Transform }
    for lg, id in entities {
        coll := level_colliders[lg.collider] 
        if lg.crack_time == 0 || et < lg.crack_time + BREAK_DELAY {
            if filter <= lg.attributes {
                if sphere_aabb_collision(position, PLAYER_SPHERE_SQ_RADIUS, lg.aabb) {
                    vertices := transformed_coll_vertices[tv_offset:tv_offset + len(coll.vertices)] 
                    l := len(coll.indices)
                    for i := 0; i <= l - 3; i += 3 {
                        t0 := vertices[coll.indices[i]]
                        t1 := vertices[coll.indices[i+1]]
                        t2 := vertices[coll.indices[i+2]]
                        did_collide, t, normal, contact := player_lg_collision(
                            position,
                            PLAYER_SPHERE_RADIUS,
                            t0, t1, t2,
                            player_velocity,
                            player_velocity_len,
                            player_velocity_normal,
                            ppos_end,
                            contact_ray,
                            GROUNDED_RADIUS2
                        )
                        if did_collide {
                            append(&collisions, Collision{id, normal, t})
                        }
                        got_contact = got_contact || contact
                    }
                }
            }         
        }
        tv_offset += len(coll.vertices)
    }
    return
}

updated_contact_state :: proc(state: Player_States, collisions: []Collision, et: f32, got_contact: bool, best_plane_normal: [3]f32) -> Player_States {
    if !got_contact && (state == .ON_GROUND || state == .ON_WALL || state == .ON_SLOPE){
        return .IN_AIR
    }
    if best_plane_normal.y >= 0.85 && best_plane_normal.y < 100.0 {
        return .ON_GROUND
    } else if .2 <= best_plane_normal.y && best_plane_normal.y < .85 {
        return .ON_SLOPE
    } else if best_plane_normal.y < .2 && state != .ON_GROUND {
        return .ON_WALL
    }
    return state
}

updated_left_ground :: proc(state: Player_States, left_ground: f32, elapsed_time: f32) -> f32 {
    if state == .ON_GROUND {
        return elapsed_time
    }
    return left_ground 
}

updated_left_wall :: proc(state: Player_States, left_wall: f32, elapsed_time: f32) -> f32 {
    if state == .ON_WALL {
        return elapsed_time
    }
    return left_wall
}

updated_left_slope :: proc(state: Player_States, left_slope: f32, elapsed_time: f32) -> f32 {
    if state == .ON_SLOPE {
        return elapsed_time
    }
    return left_slope 
}

updated_touch_time :: proc(state: Player_States, old_state: Player_States, touch_time: f32, elapsed_time: f32) -> f32 {
    if state != old_state {
        return elapsed_time
    }
    return touch_time 
}

updated_contact_ray :: proc(contact_ray: [3]f32, best_plane_normal: [3]f32) -> [3]f32 {
    if best_plane_normal.y < 100.0 {
        return -best_plane_normal * GROUND_RAY_LEN
    }
    return contact_ray
}


updated_can_press_jump :: proc(can_press_jump: bool, jumped: bool, is: Input_State, on_surface: bool) -> bool {
    if jumped {
        return false
    }
    return can_press_jump || !is.z_pressed && on_surface
}

updated_tgt_particle_displacement :: proc(jumped: bool, tgt_particle_displacement: [3]f32, velocity: [3]f32, state: Player_States) -> [3]f32 {
    new_tgt_particle_displacement := jumped ? velocity : tgt_particle_displacement
    if state != .ON_GROUND {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, velocity, TGT_PARTICLE_DISPLACEMENT_LERP)
    } else {
        new_tgt_particle_displacement = la.lerp(new_tgt_particle_displacement, [3]f32{0, 0, 0}, TGT_PARTICLE_DISPLACEMENT_LERP)
    }
    return new_tgt_particle_displacement
}


updated_ground_move_dirs :: proc(state: Player_States, ground_x: [3]f32, ground_z: [3]f32, best_plane_normal: [3]f32) -> (x: [3]f32, z: [3]f32) {
    if best_plane_normal.y < 100 && (state == .ON_GROUND || state == .ON_SLOPE) {
        x = [3]f32{1, 0, 0}
        z = [3]f32{0, 0, -1}
        x = la.normalize(x - la.dot(x, best_plane_normal) * best_plane_normal)
        z = la.normalize(z - la.dot(z, best_plane_normal) * best_plane_normal)
        return
    }
    return ground_x, ground_z
}

update_player_contact_state :: proc(cs: Contact_State, collisions: []Collision, got_contact: bool, elapsed_time: f32) -> Contact_State {
    cs := cs
    best_plane_normal: [3]f32 = {100, 100, 100}
    for coll in collisions {
        if abs(coll.normal.y) < best_plane_normal.y {
            best_plane_normal = coll.normal
        }
    }
    old_state := cs.state
    cs.state                  = updated_contact_state(cs.state, collisions[:], elapsed_time, got_contact, best_plane_normal)
    cs.touch_time             = updated_touch_time(cs.state, old_state, cs.touch_time, elapsed_time)
    cs.left_ground            = updated_left_ground(cs.state, cs.left_ground, elapsed_time)
    cs.left_slope             = updated_left_slope(cs.state, cs.left_slope, elapsed_time)
    cs.left_wall              = updated_left_wall(cs.state, cs.left_wall, elapsed_time)
    cs.contact_ray            = updated_contact_ray(cs.contact_ray, best_plane_normal)
    cs.ground_x, cs.ground_z = updated_ground_move_dirs(cs.state, cs.ground_x, cs.ground_z, best_plane_normal)
    return cs
}

updated_camera_state :: proc(cs: Camera_State, player_pos: [3]f32) -> Camera_State {
    cs := cs 
    cs.prev_position = cs.position
    cs.prev_target = cs.target
    tgt_y := player_pos.y + CAMERA_PLAYER_Y_OFFSET
    tgt_z := player_pos.z + CAMERA_PLAYER_Z_OFFSET
    tgt_x := player_pos.x + CAMERA_PLAYER_X_OFFSET
    tgt : [3]f32 = {tgt_x, tgt_y, tgt_z}
    cs.position = math.lerp(cs.position, tgt, f32(CAMERA_POS_LERP))
    cs.target.x = math.lerp(cs.target.x, player_pos.x, f32(CAMERA_X_LERP))
    cs.target.y = math.lerp(cs.target.y, player_pos.y, f32(CAMERA_Y_LERP))
    cs.target.z = math.lerp(cs.target.z, player_pos.z, f32(CAMERA_Z_LERP))
    return cs
}

updated_crunch_pts :: proc(crunch_pts: [][4]f32, elapsed_time: f32, player_pos: [3]f32, cs: Camera_State, did_bunny_hop: bool, new_crunch_time: f32) -> (new_crunch_pts: [dynamic][4]f32) {
    new_crunch_pts = make([dynamic][4]f32)
    for cpt in crunch_pts {
        append(&new_crunch_pts, cpt)
    }
    idx := 0
    for _ in 0..<len(new_crunch_pts) {
        cpt := new_crunch_pts[idx]
        if elapsed_time - cpt[3] > 3000 {
            ordered_remove(&new_crunch_pts, idx) 
        } else {
            idx += 1
        }
    }
    if did_bunny_hop {
        bg_crunch_pt := cs.position + la.normalize0(player_pos - cs.position) * 10000.0;
        append(&new_crunch_pts, [4]f32{bg_crunch_pt.x, bg_crunch_pt.y, bg_crunch_pt.z, new_crunch_time})
    }
    return
}

