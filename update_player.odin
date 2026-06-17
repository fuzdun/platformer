package main

import "core:math"
import la "core:math/linalg"
import hm "core:container/handle_map"

INFINITE_HOP :: true

GROUND_BASE: f32 : -14.00

first_frame := true

set_state :: proc(pls: ^Player_State, next: Mode_State) {
    switch &s in next {
    case On_Surface:
        pls.state = s
    case Airborne:
        pls.state = s
    case Jumping:
        pls.state = s
    }
}

get_collisions :: proc (
    pls: Player_State,
    lgs: ^Level_Geometry_State,
    physics_map: []Physics_Segment,
    et: f32,
    dt: f32,
) -> (
    collided: bool,
    collision: Collision,
    got_contact: bool = false
){
    player_velocity := pls.velocity * dt
    player_velocity_len := la.length(player_velocity)
    player_velocity_normal := la.normalize(player_velocity)
    ppos_end := pls.position + player_velocity

    segment_idx := 0 // should determine this based on entity location
    segment := physics_map[segment_idx]

    earliest_coll_t: f32 = 1000.0
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
                    got_contact = true
                    earliest_coll_t = t
                    collided_surface: Surface_Type
                    if normal.y >= NORMAL_Y_MIN_GROUND {
                        collided_surface = .GROUND
                    } else if normal.y >= NORMAL_Y_MIN_SLOPE {
                        collided_surface = .SLOPE
                    } else {
                        collided_surface = .WALL
                    }
                    collision = Collision{collider.id, normal, t, collided_surface}
                }
                // add contact
                if contact {
                    got_contact = true
                }
            }
        }
    }
    return
}

update_player :: proc(
    entities: ^Level_Geometry_State,
    pls: ^Player_State,
    gs: Game_State,
    input: Input_Attributes,
    triggers: Action_Triggers,
    physics_map: []Physics_Segment,
    elapsed_time: f32,
    delta_time: f32
) -> (
    collisions: Collision_Log,
) {
    pls.prev_position = pls.position

    if input.jump_pressed && !pls.jump_held {
        pls.jump_pressed_time = elapsed_time
    }

    pls.jump_held = input.jump_pressed

    // #####################################################
    // PRE VELOCITY
    // #####################################################

    x := [3]f32{1, 0, 0}
    y := [3]f32{0, 1, 0}

    next_z_position: = 10 - BEAT_SPACE * current_beat_progress
    pls.velocity.z = (next_z_position - pls.position.z) / delta_time

    switch &state in pls.state {

    case On_Surface:
        normalized_contact_ray := la.normalize0(pls.contact_ray)
        pls.velocity.xy *= math.pow(FRICTION, delta_time)

        if state.surface_type == .GROUND {
            surface_x := la.normalize0(x + la.dot(x, pls.contact_ray) * pls.contact_ray)
            pls.velocity += surface_x * input.dir.x * GROUND_ACCEL * delta_time
        }
        if state.surface_type == .SLOPE {
            surface_x := la.normalize0(x + la.dot(x, pls.contact_ray) * pls.contact_ray)
            pls.velocity += surface_x * input.dir.x * SLOPE_ACCEL * delta_time
            pls.velocity.y -= SLOPE_GRAV * delta_time
        }
        if state.surface_type == .WALL {
            surface_y := la.normalize0(y + la.dot(y, pls.contact_ray) * pls.contact_ray)
            pls.velocity += surface_y * input.dir.y * WALL_ACCEL * delta_time
            pls.velocity.y -= WALL_GRAV * delta_time
        }
        pls.velocity -= la.dot(pls.velocity, normalized_contact_ray) * normalized_contact_ray
        // pls.velocity.xy = la.clamp_length(pls.velocity.xy, MAX_PLAYER_SPEED)

        if triggers.jump {
            pls.jump_enabled = false
            jump_start := current_beat_progress
            jump_end: f32
            if triggers.small_hop || triggers.bunny_hop {
                jump_end = math.round(current_beat_progress) + TEST_JUMP_BEAT_COUNT
            } else {
                raw_jump_end := current_beat_progress + TEST_JUMP_BEAT_COUNT
                jump_end = math.lerp(raw_jump_end, math.round(raw_jump_end), f32(0.75))
            }
            set_state(pls, Jumping {
                jump_start = jump_start,
                jump_end = jump_end
            })
        }

    case Jumping:
        pls.velocity += input.dir.x * AIR_ACCEL * delta_time
        // pls.velocity.x = math.clamp(pls.velocity.x, -MAX_PLAYER_SPEED, MAX_PLAYER_SPEED)
        jump_midpoint := state.jump_end - ((state.jump_end - state.jump_start) * 0.5)
        arc_len := jump_midpoint - state.jump_start
        jump_progress := math.max(current_beat_progress - state.jump_start, 0)
        jump_grav := -(2.0 * TEST_JUMP_HEIGHT) / (arc_len * arc_len)
        jump_init_vel := -jump_grav * arc_len
        next_y_position := GROUND_BASE + jump_init_vel * jump_progress + 0.5 * jump_grav * jump_progress * jump_progress
        pls.velocity.y = (next_y_position - pls.position.y) / delta_time

    case Airborne:
        pls.velocity += x * input.dir.x * AIR_ACCEL * delta_time
        pls.velocity.y -= GRAV * delta_time
    }


    // #####################################################
    // APPLY VELOCITY, HANDLE COLLISIONS
    // #####################################################

    collision_ids := make(map[Handle]Collision, context.temp_allocator)
    collision: Collision
    contact: bool
    {
        collided: bool
        last_collision: Collision
        collided, last_collision, contact = get_collisions(
            pls^, entities, physics_map,
            elapsed_time, delta_time
        )
        init_velocity_len := la.length(pls.velocity)
        remaining_vel := init_velocity_len * delta_time
        target_z := pls.position.z + pls.velocity.z * delta_time
        if remaining_vel > 0 {
            velocity_normal := la.normalize(pls.velocity)
            loops := 0
            for collided && loops < 10 {
                collision = last_collision
                collided_lg := hm.get(entities, last_collision.id)
                loops += 1
                collision_ids[last_collision.id] = last_collision
                pls.position += (remaining_vel * (last_collision.t) - GROUND_BUFFER) * velocity_normal
                remaining_vel *= 1.0 - last_collision.t

                if .Hazardous in collided_lg.attributes {
                    remaining_vel = DAMAGE_VELOCITY
                    velocity_normal -= la.dot(velocity_normal, last_collision.normal) * last_collision.normal * 1.25 
                } else {
                    velocity_normal -= la.dot(velocity_normal, last_collision.normal) * last_collision.normal
                }

                remaining_vel *= (target_z - pls.position.z) / (velocity_normal.z * remaining_vel)

                pls.velocity = (velocity_normal * remaining_vel) / delta_time
                collided, last_collision, contact = get_collisions(
                    pls^, entities, physics_map,
                    elapsed_time, delta_time
                )
            }
            pls.position += velocity_normal * remaining_vel
            pls.velocity = velocity_normal * init_velocity_len
        }
    }

    collided := collision.id != Null_Handle

    // #####################################################
    // POST COLLISION 
    // #####################################################

    on_ground := false
    #partial switch &state in pls.state {
    case On_Surface:
        if !contact {
            pls.jump_enabled = false
            set_state(pls, Airborne {})
        } else {
            jump_button_pressed := input.jump_pressed
            pls.jump_enabled = pls.jump_enabled || (!jump_button_pressed && state.surface_type == .GROUND)
            on_ground = true
        }
    }
    if !on_ground && collided {
        if pls.last_touched != collision.id {
            pls.touch_time = elapsed_time
        }
        pls.last_touched = collision.id
        pls.contact_ray = -collision.normal * CONTACT_RAY_LEN 
        set_state(pls, On_Surface{
            surface_type = collision.surface,
        })
    }

    // handle checkpoint / restart
    // -------------------------------------------
    if triggers.restart {
        pls.velocity = [3]f32{0, 0, 0}
        pls.position = INIT_PLAYER_POS
        set_state(pls, Airborne {})
    }

    if triggers.checkpoint {
        pls.velocity = [3]f32{0, 0, 0}
        pls.position = [3]f32{pls.position.x, 25, pls.position.z}
        set_state(pls, Airborne{})
    }

    // handle round end
    // -------------------------------------------
    if gs.time_remaining == 0 {
        pls.position = [3]f32{5000, 5000, 5000}
        pls.velocity = 0
    }

    // fmt.println(pls.velocity)

    return collision_ids
}

