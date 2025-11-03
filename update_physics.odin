package main
import "core:math"
import "core:fmt"
import la "core:math/linalg"

get_collisions_and_update_contact_state :: proc(
    lgs: #soa[]Level_Geometry,
    position: [3]f32,
    velocity: [3]f32,
    contact_ray: [3]f32,
    level_colliders: [SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
    cs: Contact_State,
    sliding: bool,
    et: f32,
    dt: f32,
) -> (
    collided: bool,
    collision: Collision,
    contacts: [dynamic]int,
    new_cs: Contact_State
){
    earliest_coll_t: f32 = 1000.0
    contacts = make([dynamic]int)
    player_velocity := velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := position + player_velocity

    transformed_coll_vertices := static_collider_vertices
    tv_offset := 0

    filter: Level_Geometry_Attributes = { .Collider }
    for lg, id in lgs {
        coll := level_colliders[lg.collider] 
        if (lg.shatter_data.crack_time == 0 || et < lg.shatter_data.crack_time + BREAK_DELAY) && lg.shatter_data.smash_time == 0 {
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

    best_plane_normal := collided ? collision.normal : {100, 100, 100}
    ignore_contact := sliding && (.Slide_Zone in lgs[collision.id].attributes)
    
    // update contact state
    new_surface_contact_state := cs.state
    if !(collided && .Hazardous in lgs[collision.id].attributes) {
        on_surface := (cs.state == .ON_GROUND || cs.state == .ON_WALL || cs.state == .ON_SLOPE)
        if len(contacts) == 0 && on_surface {
            new_surface_contact_state = .IN_AIR
        } else if best_plane_normal.y >= 0.85 && best_plane_normal.y < 100.0 {
            new_surface_contact_state = .ON_GROUND
        } else if .2 <= best_plane_normal.y && best_plane_normal.y < .85 {
            new_surface_contact_state = .ON_SLOPE
        } else if best_plane_normal.y < .2 && cs.state != .ON_GROUND {
            new_surface_contact_state = .ON_WALL
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
        new_contact_ray = -best_plane_normal * GROUND_RAY_LEN
    }

    // update ground_move_dirs
    new_ground_x := cs.ground_x
    new_ground_z := cs.ground_z
    on_slope_or_ground := new_surface_contact_state == .ON_GROUND || new_surface_contact_state == .ON_SLOPE
    if !ignore_contact && best_plane_normal.y < 100 && on_slope_or_ground {
        x := [3]f32{1, 0, 0}
        z := [3]f32{0, 0, -1}
        new_ground_x = la.normalize0(x - la.dot(x, best_plane_normal) * best_plane_normal)
        new_ground_z = la.normalize0(z - la.dot(z, best_plane_normal) * best_plane_normal)
    }

    new_cs = cs
    new_cs.state = new_surface_contact_state;
    new_cs.touch_time = new_touch_time;
    new_cs.left_ground = new_left_ground;
    new_cs.left_slope = new_left_slope;
    new_cs.left_wall = new_left_wall;
    new_cs.contact_ray = new_contact_ray;
    new_cs.ground_x = new_ground_x;
    new_cs.ground_z = new_ground_z;
    return
}


apply_velocity :: proc(
    contact_state: Contact_State,
    position: [3]f32,
    velocity: [3]f32,
    dashing: bool,
    sliding: bool,
    entities: #soa[]Level_Geometry, 
    level_colliders: [SHAPE]Collider_Data,
    static_collider_vertices: [dynamic][3]f32,
    elapsed_time: f32,
    delta_time: f32
) -> (
    new_contact_state: Contact_State,
    new_position: [3]f32,
    new_velocity: [3]f32,
    collision_ids: map[int]struct{},
    contact_ids: map[int]struct{}
) {
    new_position = position
    new_velocity = velocity
    collision_ids = make(map[int]struct{})
    collided: bool
    collision: Collision
    contacts: [dynamic]int
    collided, collision, contacts, new_contact_state = get_collisions_and_update_contact_state(
        entities[:], position, velocity,
        contact_state.contact_ray, level_colliders,
        static_collider_vertices, contact_state,
        sliding, elapsed_time, delta_time
    )
    for contact in contacts {
        contact_ids[contact] = {}
    }
    init_velocity_len := la.length(velocity)
    remaining_vel := init_velocity_len * delta_time
    if remaining_vel > 0 {
        velocity_normal := la.normalize(velocity)
        loops := 0
        if !collided && len(contacts) > 0{
            new_contact_state.last_touched = contacts[0]
        }
        for collided && loops < 10 {
            loops += 1
            new_contact_state.last_touched = collision.id
            collision_ids[collision.id] = {}
            new_position += (remaining_vel * (collision.t) - .01) * velocity_normal
            remaining_vel *= 1.0 - collision.t
            if .Dash_Breakable in entities[collision.id].attributes && dashing {
               // remaining_vel = BREAK_BOOST_VELOCITY 
            // } else if .Bouncy in entities[collision.id].attributes {
                // remaining_vel = BOUNCE_VELOCITY
                // velocity_normal += la.dot(velocity_normal, collision.normal) * collision.normal
            } else if .Slide_Zone in entities[collision.id].attributes && sliding{
            //    remaining_vel = BREAK_BOOST_VELOCITY 
            } else if .Hazardous in entities[collision.id].attributes {
                remaining_vel = DAMAGE_VELOCITY
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal * 1.25 
            } else {
                velocity_normal -= la.dot(velocity_normal, collision.normal) * collision.normal
            }
            new_velocity = (velocity_normal * remaining_vel) / delta_time
            delete(contacts)
            collided, collision, contacts, new_contact_state = get_collisions_and_update_contact_state(
                entities[:], position, velocity,
                contact_state.contact_ray, level_colliders,
                static_collider_vertices, contact_state,
                sliding, elapsed_time, delta_time
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

