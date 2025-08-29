package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"


// ================
// VELOCITY UPDATES
// ================
apply_directional_input_to_velocity :: proc(pls: Player_State, is: Input_State, velocity: [3]f32, elapsed_time: f32, delta_time: f32) -> [3]f32 {
    if elapsed_time < pls.hurt_t + DAMAGE_LEN {
        return pls.velocity
    }
    velocity := velocity
    cs := pls.contact_state
    move_spd := P_ACCEL
    if cs.state == .ON_SLOPE {
        move_spd =  SLOPE_SPEED
    } else if cs.state == .IN_AIR {
        move_spd =  AIR_SPEED
    }
    grounded := cs.state == .ON_GROUND || cs.state == .ON_SLOPE
    right_vec := grounded ? cs.ground_x : [3]f32{1, 0, 0}
    fwd_vec := grounded ? cs.ground_z : [3]f32{0, 0, -1}
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


apply_friction_to_velocity :: proc(pls: Player_State, is: Input_State, velocity: [3]f32, delta_time: f32) -> [3]f32 {
    got_dir_input :=  is.a_pressed || is.s_pressed || is.d_pressed || is.w_pressed || is.hor_axis != 0 || is.vert_axis != 0
    return (pls.contact_state.state == .ON_GROUND && !got_dir_input) ? velocity * math.pow(GROUND_FRICTION, delta_time) : velocity
}


apply_gravity_to_velocity :: proc(pls: Player_State, velocity: [3]f32, delta_time: f32) -> [3]f32 {
    cs := pls.contact_state
    if cs.state != .ON_GROUND {
        down: [3]f32 = {0, -1, 0}
        norm_contact := la.normalize(cs.contact_ray)
        grav_force := GRAV
        if cs.state == .ON_SLOPE {
            grav_force = SLOPE_GRAV
        }
        if cs.state == .ON_WALL {
            grav_force = WALL_GRAV
        }
        if cs.state == .ON_WALL || cs.state == .ON_SLOPE {
            down -= la.dot(norm_contact, down) * norm_contact
        }
        return velocity + down * grav_force * delta_time
    }
    return velocity
}


apply_jumps_to_velocity :: proc(pls: Player_State, is: Input_State, velocity: [3]f32, elapsed_time: f32) -> [3]f32 {
    velocity := velocity
    if did_bunny_hop(pls, elapsed_time) {
        velocity.y = GROUND_BUNNY_V_SPEED
        if la.length(velocity.xz) > MIN_BUNNY_XZ_VEL {
            velocity.xz += la.normalize(velocity.xz) * GROUND_BUNNY_H_SPEED
        }
    } 
    if ground_jumped(pls, is, elapsed_time) {
        velocity.y = P_JUMP_SPEED
    } else if slope_jumped(pls, is, elapsed_time) {
        velocity += -la.normalize(pls.contact_state.contact_ray) * SLOPE_JUMP_FORCE
        velocity.y = SLOPE_V_JUMP_FORCE
    } else if wall_jumped(pls, is, elapsed_time) {
        velocity.y = P_JUMP_SPEED
        velocity += -pls.contact_state.contact_ray * WALL_JUMP_FORCE 
    }
    return velocity
}


apply_dash_to_velocity :: proc(pls: Player_State, velocity: [3]f32, elapsed_time: f32) -> [3]f32 {
    velocity := velocity
    state := pls.contact_state.state
    dash_expired := f32(elapsed_time) > pls.dash_state.dash_time + DASH_LEN
    hit_surface := state == .ON_WALL || state == .ON_GROUND || state == .ON_WALL
    if pls.dash_state.dashing {
        velocity = la.normalize(pls.dash_state.dash_end_pos - pls.dash_state.dash_start_pos) * DASH_SPD
    } 
    return velocity
}


apply_slide_to_velocity :: proc(pls: Player_State, velocity: [3]f32, elapsed_time: f32) -> [3]f32 {
    velocity := velocity
    state := pls.contact_state.state
    slide_expired := f32(elapsed_time) > pls.slide_state.slide_time + SLIDE_LEN
    if pls.slide_state.sliding {
        // if slide_expired || !on_surface(pls) {
            velocity = pls.slide_state.slide_dir * SLIDE_SPD 
        // } else {
        //     velocity = 0
        // }
    }
    return velocity
}

// apply_break_to_velocity :: proc(pls: Player_State, velocity: [3]f32, )


apply_restart_to_velocity :: proc(is: Input_State, velocity: [3]f32) -> [3]f32 {
    return is.r_pressed ? {0, 0, 0} : velocity
}


// ===========================
// COLLISION / CONTACT UPDATES
// ===========================
apply_jump_to_player_state :: proc(pls: Player_State, is: Input_State, elapsed_time: f32) -> Player_States {
    return !pls.slide_state.sliding && jumped(pls, is, elapsed_time) ? .IN_AIR : pls.contact_state.state
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
    collided: bool,
    collision: Collision,
    contacts: [dynamic]int
) {
    earliest_coll_t: f32 = 1000.0
    contacts = make([dynamic]int)
    player_velocity := velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := position + player_velocity

    transformed_coll_vertices := static_collider_vertices
    tv_offset := 0

    filter: Level_Geometry_Attributes = { .Collider }
    for lg, id in entities {
        coll := level_colliders[lg.collider] 
        if (lg.crack_time == 0 || et < lg.crack_time + BREAK_DELAY) && lg.break_time == 0 {
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
                        if did_collide && t < earliest_coll_t {
                            collided = true
                            earliest_coll_t = t
                            collision = Collision{id, normal, t}
                        }
                        if contact {
                            append(&contacts, id)
                        }
                    }
                }
            }         
        }
        tv_offset += len(coll.vertices)
    }
    return
}


updated_contact_state :: proc(state: Player_States, hit_hazard: bool, et: f32, got_contact: bool, best_plane_normal: [3]f32) -> Player_States {
    if hit_hazard {
        return state
    }
    if !got_contact && (state == .ON_GROUND || state == .ON_WALL || state == .ON_SLOPE) {
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


updated_touch_time :: proc(state: Player_States, old_state: Player_States, touch_time: f32, elapsed_time: f32) -> f32 {
    if state != old_state && state != .IN_AIR {
        return elapsed_time
    }
    return touch_time 
}


updated_left_ground :: proc(state: Player_States, left_ground: f32, elapsed_time: f32) -> f32 {
    if state == .ON_GROUND {
        return elapsed_time
    }
    return left_ground 
}


updated_left_slope :: proc(state: Player_States, left_slope: f32, elapsed_time: f32) -> f32 {
    if state == .ON_SLOPE {
        return elapsed_time
    }
    return left_slope 
}


updated_left_wall :: proc(state: Player_States, left_wall: f32, elapsed_time: f32) -> f32 {
    if state == .ON_WALL {
        return elapsed_time
    }
    return left_wall
}


updated_contact_ray :: proc(contact_ray: [3]f32, best_plane_normal: [3]f32) -> [3]f32 {
    if best_plane_normal.y < 100.0 {
        return -best_plane_normal * GROUND_RAY_LEN
    }
    return contact_ray
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


update_player_contact_state :: proc(cs: Contact_State, collided: bool, collision: Collision, lgs: #soa[]Level_Geometry, contacts: []int, elapsed_time: f32) -> Contact_State {
    cs := cs
    best_plane_normal: [3]f32 = {100, 100, 100}
    if collided {
        best_plane_normal = collision.normal
    }
    got_contact := len(contacts) > 0
    hit_hazard := collided && .Hazardous in lgs[collision.id].attributes
    old_state := cs.state
    cs.state                  = updated_contact_state(cs.state, hit_hazard, elapsed_time, got_contact, best_plane_normal)
    cs.touch_time             = updated_touch_time(cs.state, old_state, cs.touch_time, elapsed_time)
    cs.left_ground            = updated_left_ground(cs.state, cs.left_ground, elapsed_time)
    cs.left_slope             = updated_left_slope(cs.state, cs.left_slope, elapsed_time)
    cs.left_wall              = updated_left_wall(cs.state, cs.left_wall, elapsed_time)
    cs.contact_ray            = updated_contact_ray(cs.contact_ray, best_plane_normal)
    cs.ground_x, cs.ground_z  = updated_ground_move_dirs(cs.state, cs.ground_x, cs.ground_z, best_plane_normal)
    return cs
}


apply_velocity :: proc(
    contact_state: Contact_State,
    position: [3]f32,
    velocity: [3]f32,
    dashing: bool,
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
    collided, collision, contacts := get_collisions(
        entities[:],
        position,
        velocity,
        contact_state.contact_ray,
        level_colliders, static_collider_vertices, elapsed_time, delta_time
    )
    new_contact_state = update_player_contact_state(
        contact_state,
        collided,
        collision,
        entities,
        contacts[:],
        elapsed_time
    )
    init_velocity_len := la.length(velocity)
    remaining_vel := init_velocity_len * delta_time
    if remaining_vel > 0 {
        velocity_normal := la.normalize(velocity)
        loops := 0
        for collided && loops < 10 {
            loops += 1
            new_contact_state.last_touched = collision.id
            collision_ids[collision.id] = {}
            new_position += (remaining_vel * (collision.t) - .01) * velocity_normal
            remaining_vel *= 1.0 - collision.t
            if .Dash_Breakable in entities[collision.id].attributes && dashing {
               remaining_vel = BREAK_BOOST_VELOCITY 
            } else if .Hazardous in entities[collision.id].attributes {
                remaining_vel = DAMAGE_VELOCITY
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal * 1.25 
            } else {
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal
            }
            new_velocity = (velocity_normal * remaining_vel) / delta_time
            collided, collision, contacts = get_collisions(
                entities,
                new_position,
                new_velocity,
                contact_state.contact_ray,
                level_colliders,
                static_collider_vertices,
                elapsed_time,
                delta_time
            )
            new_contact_state = update_player_contact_state(
                new_contact_state,
                collided,
                collision,
                entities,
                contacts[:],
                elapsed_time)
        }
        new_position += velocity_normal * remaining_vel
        new_velocity = velocity_normal * init_velocity_len
    }
    return
}


// ================
// POSITION UPDATES
// ================
apply_dash_to_position :: proc(pls: Player_State, position: [3]f32, elapsed_time: f32) -> [3]f32 {
    if pls.dash_state.dashing {
        dash_t := (f32(elapsed_time) - pls.dash_state.dash_time) / DASH_LEN
        dash_delta := pls.dash_state.dash_end_pos - pls.dash_state.dash_start_pos
        return pls.dash_state.dash_start_pos + dash_delta * dash_t
    }
    return position
}


// apply_slide_to_position :: proc(pls: Player_State, position: [3]f32, elapsed_time: f32) -> [3]f32 {
//     sls := pls.slide_state
//     if sls.sliding {
//         slide_t := (f32(elapsed_time) - pls.slide_state.slide_time) / SLIDE_LEN
//         return sls.slide_start_pos + sls.slide_dir * SLIDE_DIST * slide_t
//     }
//     return position
// }


apply_restart_to_position :: proc(is: Input_State, position: [3]f32) -> [3]f32 {
  return is.r_pressed ? INIT_PLAYER_POS : position
}

