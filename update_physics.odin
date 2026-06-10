package main

import la "core:math/linalg"
import hm "core:container/handle_map"

NORMAL_Y_MIN_GROUND :: 0.85
NORMAL_Y_MIN_SLOPE :: 0.2


build_physics_map :: proc(lgs: ^Level_Geometry_State, colliders: [SHAPE]Mesh, et: f32) -> (physics_map: []Physics_Segment) {
    physics_map = make([]Physics_Segment, PHYSICS_SEGMENT_COUNT, context.temp_allocator)
    for segment_idx in 0..<5 {
        physics_map[segment_idx] = make(Physics_Segment, context.temp_allocator)
    }
    lg_it := hm.iterator_make(lgs)
    for lg, lg_idx in hm.iterate(&lg_it) {
        if .Collider not_in lg.attributes || !(lg.shatter_data.crack_time == 0 || et < lg.shatter_data.crack_time + BREAK_DELAY) && lg.shatter_data.smash_time == 0 {
            continue
        }
        segment_idx: int = 0 //int(math.floor(lg.transform.position.z / PHYSICS_SEGMENT_SIZE)) 
        //segment := physics_map[segment_idx]
        shape_data := colliders[lg.shape]
        trans_mat := trans_to_mat4(lg.transform)
        coll: Collider
        coll.id = lg_idx
        coll.vertices = make([][3]f32, len(shape_data.vertices), context.temp_allocator)
        for vertex, vertex_i in shape_data.vertices {
            coll.vertices[vertex_i] = (trans_mat * [4]f32{vertex.x, vertex.y, vertex.z, 1.0}).xyz
        }
        coll.indices = make([]u16, len(shape_data.indices), context.temp_allocator)
        copy(coll.indices, shape_data.indices)
        coll.aabb = vertices_to_aabb(coll.vertices)
        append(&physics_map[segment_idx], coll)
    }
    return
}

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
    pls: ^Player_State,
    lgs: ^Level_Geometry_State,
    physics_map: []Physics_Segment,
    et: f32,
    dt: f32,
) -> (
    collided: bool,
    collision: Collision,
    contacts: [dynamic]Handle,
    // new_cs: Contact_State,
    touched_ground: bool
){
    earliest_coll_t: f32 = 1000.0
    contacts = make([dynamic]Handle, context.temp_allocator)
    player_velocity := pls.velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := pls.position + player_velocity
    // cs := pls.contact_state

    segment_idx := 0 // should determine this based on entity location
    segment := physics_map[segment_idx]

    for collider in segment {
        lg,_ := hm.get(lgs, collider.id) 
        // check AABB collision
        if sphere_aabb_collision(pls.position, PLAYER_SPHERE_SQ_RADIUS, collider.aabb) {
            for i := 0; i < len(collider.indices); i += 3 {
                triangle_indices := collider.indices[i:i+3]
                t0 := collider.vertices[triangle_indices[0]]
                t1 := collider.vertices[triangle_indices[1]]
                t2 := collider.vertices[triangle_indices[2]]
                // check for triangle collision and surface contact
                did_collide, t, normal, contact := player_triangle_collision(
                    pls.position,
                    PLAYER_SPHERE_RADIUS,
                    t0, t1, t2,
                    player_velocity,
                    player_velocity_len,
                    player_velocity_normal,
                    ppos_end,
                    pls.contact_ray,
                    CONTACT_RAY_LEN2,
                )
                // update closest collision
                if did_collide && t < earliest_coll_t {
                    collided = true
                    earliest_coll_t = t
                    collision = Collision{collider.id, normal, t, .GROUND}
                }
                // add contact
                if contact {
                    append(&contacts, collider.id)
                }
            }
        }
    }

    collided_lg := hm.get(lgs, collision.id)
    // ignore_contact := sliding && (.Slide_Zone in collided_lg.attributes)

    new_surface_contact: Surface_Type//= cs.state
    if !(collided && .Hazardous in collided_lg.attributes) {
        if len(contacts) == 0 {
            set_state(pls, Airborne {})
        } else if collided {
            if pls.last_touched != collision.id {
                pls.touch_time = et
            }
            pls.contact_ray = -collision.normal * CONTACT_RAY_LEN
            pls.last_touched = collision.id
            if collision.normal.y >= NORMAL_Y_MIN_GROUND {
                collision.surface = .GROUND
                pls.left_ground = et
                touched_ground = true
            } else if collision.normal.y >= NORMAL_Y_MIN_SLOPE {
                collision.surface = .SLOPE
                pls.left_slope = et
                touched_ground = true
            } else {
                pls.left_wall = et
                collision.surface = .WALL
            }
        }
    }

    // if collided {
    //     set_state(pls, On_Surface {
    //         surface_type = .GROUND,
    //     })
    // }
    //
    return
}


apply_velocity :: proc(
    pls: ^Player_State,
    entities: ^Level_Geometry_State, 
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) -> (
    collision_ids: Collision_Log,
    last_collision: Maybe(Collision),
    touched_ground: bool
) {
    collision_ids = make(map[Handle]struct{}, context.temp_allocator)
    collided: bool
    collision: Collision
    contacts: [dynamic]Handle
    collided, collision, contacts, touched_ground = get_collisions_and_update_contact_state(
        pls, entities, physics_map,
        elapsed_time, delta_time
    )
    init_velocity_len := la.length(pls.velocity)
    remaining_vel := init_velocity_len * delta_time
    target_z := pls.position.z + pls.velocity.z * delta_time
    if remaining_vel > 0 {
        velocity_normal := la.normalize(pls.velocity)
        loops := 0
        for collided && loops < 10 {
            collided_lg := hm.get(entities, collision.id)
            loops += 1
            collision_ids[collision.id] = {}
            pls.position += (remaining_vel * (collision.t) - GROUND_BUFFER) * velocity_normal
            remaining_vel *= 1.0 - collision.t

            if .Hazardous in collided_lg.attributes {
                remaining_vel = DAMAGE_VELOCITY
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal * 1.25 
            } else {
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal
            }

            remaining_vel *= (target_z - pls.position.z) / (velocity_normal.z * remaining_vel)

            pls.velocity = (velocity_normal * remaining_vel) / delta_time
            collided, collision, contacts, touched_ground = get_collisions_and_update_contact_state(
                pls, entities, physics_map,
                elapsed_time, delta_time
            )
        }
        pls.position += velocity_normal * remaining_vel
        pls.velocity = velocity_normal * init_velocity_len
    }
    return
}

