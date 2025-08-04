package main

import la "core:math/linalg"
import "core:math"

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

updated_crunch_pts :: proc(crunch_pts: [][4]f32, elapsed_time: f32) -> (new_crunch_pts: [dynamic][4]f32) {
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
    return
}

