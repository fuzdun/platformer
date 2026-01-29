package main

import "core:math"
import "core:fmt"
import la "core:math/linalg"

NORMAL_Y_MIN_GROUND :: 0.85
NORMAL_Y_MIN_SLOPE :: 0.2


get_particle_collisions :: proc(
    particles: $T/Particle_Buffer,
    physics_map: []Physics_Segment,
) -> (collisions: [dynamic]Particle_Collision) {
    collisions = make([dynamic]Particle_Collision, context.temp_allocator)
    particle_loop: for particle_pos, particle_idx in particles.particles.values {
        segment_idx := 0 
        segment := physics_map[segment_idx]
        for collider in segment {
            if sphere_aabb_collision(particle_pos.xyz, 1.0, collider.aabb) {
                for i := 0; i < len(collider.indices); i += 3 {
                    triangle_indices := collider.indices[i:i+3]
                    t0 := collider.vertices[triangle_indices[0]]
                    t1 := collider.vertices[triangle_indices[1]]
                    t2 := collider.vertices[triangle_indices[2]]
                    if collided, collision_normal := particle_triangle_collision(particle_pos.xyz, 1.0, t0, t1, t2); collided {
                        append(&collisions, Particle_Collision{particle_idx, collision_normal})
                        continue particle_loop
                    }
                }
            }
        } 
    }
    return
}

get_collisions_and_update_contact_state :: proc(
    lgs: #soa[]Level_Geometry,
    position: [3]f32,
    velocity: [3]f32,
    physics_map: []Physics_Segment,
    cs: Contact_State,
    sliding: bool,
    et: f32,
    dt: f32,
) -> (
    collided: bool,
    collision: Collision,
    contacts: [dynamic]int,
    new_cs: Contact_State,
    touched_ground: bool
){
    earliest_coll_t: f32 = 1000.0
    contacts = make([dynamic]int, context.temp_allocator)
    player_velocity := velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := position + player_velocity

    segment_idx := 0 // should determine this based on entity location
    segment := physics_map[segment_idx]

    for collider in segment {
        lg := lgs[collider.id]
        // check AABB collision
        if sphere_aabb_collision(position, PLAYER_SPHERE_SQ_RADIUS, collider.aabb) {
            for i := 0; i < len(collider.indices); i += 3 {
                triangle_indices := collider.indices[i:i+3]
                t0 := collider.vertices[triangle_indices[0]]
                t1 := collider.vertices[triangle_indices[1]]
                t2 := collider.vertices[triangle_indices[2]]
                // check for triangle collision and surface contact
                did_collide, t, normal, contact := player_triangle_collision(
                    position,
                    PLAYER_SPHERE_RADIUS,
                    t0, t1, t2,
                    player_velocity,
                    player_velocity_len,
                    player_velocity_normal,
                    ppos_end,
                    cs.contact_ray,
                    CONTACT_RAY_LEN2,
                )
                // update closest collision
                if did_collide && t < earliest_coll_t {
                    collided = true
                    earliest_coll_t = t
                    collision = Collision{collider.id, normal, t}
                }
                // add contact
                if contact {
                    append(&contacts, collider.id)
                }
            }
        }
    }

    best_plane_normal := collided ? collision.normal : {100, 100, 100}
    ignore_contact := sliding && (.Slide_Zone in lgs[collision.id].attributes)

    // update contact state
    new_surface_contact_state := cs.state
    if !(collided && .Hazardous in lgs[collision.id].attributes) {
        on_surface := (cs.state == .ON_GROUND || cs.state == .ON_WALL || cs.state == .ON_SLOPE)
        // left surface
        if len(contacts) == 0 && on_surface {
            new_surface_contact_state = .IN_AIR
            // else, update state based on contact angle
        } else if collided {
            if best_plane_normal.y >= NORMAL_Y_MIN_GROUND {
                new_surface_contact_state = .ON_GROUND
                touched_ground = true
            } else if best_plane_normal.y >= NORMAL_Y_MIN_SLOPE {
                new_surface_contact_state = .ON_SLOPE
                touched_ground = true
            } else {
                new_surface_contact_state = .ON_WALL
            }
        }
    }

    // update touch time
    new_touch_time := cs.touch_time
    if new_surface_contact_state != cs.state && new_surface_contact_state != .IN_AIR {
        new_touch_time = et
    }

    // update left ground
    new_left_ground := cs.left_ground
    if new_surface_contact_state == .ON_GROUND {
        new_left_ground = et
    }

    // update left_slope
    new_left_slope := cs.left_slope
    if new_surface_contact_state == .ON_SLOPE {
        new_left_slope = et
    }

    // update left_wall
    new_left_wall := cs.left_wall
    if new_surface_contact_state == .ON_WALL {
        new_left_wall = et
    }

    // update contact ray
    new_contact_ray := cs.contact_ray
    if !ignore_contact && best_plane_normal.y < 100.0 {
        new_contact_ray = -best_plane_normal * CONTACT_RAY_LEN
    }

    new_cs = cs
    new_cs.state = new_surface_contact_state
    new_cs.touch_time = new_touch_time
    new_cs.left_ground = new_left_ground
    new_cs.left_slope = new_left_slope
    new_cs.left_wall = new_left_wall
    new_cs.contact_ray = new_contact_ray
    new_cs.last_touched = cs.last_touched
    return
}


apply_velocity :: proc(
    contact_state: Contact_State,
    position: [3]f32,
    velocity: [3]f32,
    dashing: bool,
    sliding: bool,
    entities: #soa[]Level_Geometry, 
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) -> (
    new_contact_state: Contact_State,
    new_position: [3]f32,
    new_velocity: [3]f32,
    collision_ids: map[int]struct{},
    contact_ids: map[int]struct{},
    touched_ground: bool
) {
    new_position = position
    new_velocity = velocity
    collision_ids = make(map[int]struct{}, context.temp_allocator)
    contact_ids = make(map[int]struct{}, context.temp_allocator)
    collided: bool
    collision: Collision
    contacts: [dynamic]int
    collided, collision, contacts, new_contact_state, touched_ground = get_collisions_and_update_contact_state(
        entities[:], position, velocity,
        physics_map, contact_state, sliding,
        elapsed_time, delta_time
    )
    for contact in contacts {
        contact_ids[contact] = {}
    }
    init_velocity_len := la.length(velocity)
    remaining_vel := init_velocity_len * delta_time
    if remaining_vel > 0 {
        velocity_normal := la.normalize(velocity)
        loops := 0
        if !collided && len(contacts) > 0 {
            new_contact_state.last_touched = contacts[0]
        }
        for collided && loops < 10 {
            loops += 1
            new_contact_state.last_touched = collision.id
            collision_ids[collision.id] = {}
            if .Dash_Breakable in entities[collision.id].attributes && dashing {
                break
            } else if .Slide_Zone in entities[collision.id].attributes && sliding {
                break
            }
            new_position += (remaining_vel * (collision.t) - GROUND_BUFFER) * velocity_normal
            remaining_vel *= 1.0 - collision.t
            if .Hazardous in entities[collision.id].attributes {
                remaining_vel = DAMAGE_VELOCITY
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal * 1.25 
            } else {
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal
            }
            new_velocity = (velocity_normal * remaining_vel) / delta_time
            collided, collision, contacts, new_contact_state, touched_ground = get_collisions_and_update_contact_state(
                entities[:], new_position, new_velocity,
                physics_map, new_contact_state, sliding,
                elapsed_time, delta_time
            )
            for contact in contacts {
                contact_ids[contact] = {}
            }
        }
        new_position += velocity_normal * remaining_vel
        new_velocity = velocity_normal * init_velocity_len
    }
    return
}

