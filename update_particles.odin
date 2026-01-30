package main

import "constants"
import "base:runtime"
import "core:math"
import "core:fmt"
import la "core:math/linalg"
import rnd "core:math/rand"
import gl "vendor:OpenGL"


update_particles :: proc(
    ptcls: ^Particle_State,
    bs: Buffer_State,
    physics_map: []Physics_Segment,
    triggers: Action_Triggers,
    pls: Player_State,
    elapsed_time: f32,
    delta_time: f32,
) {
    using constants
    cts := pls.contact_state
    normalized_contact_ray := la.normalize0(cts.contact_ray)
    surface_ortho1 := la.vector3_orthogonal(normalized_contact_ray)
    surface_ortho2 := la.cross(normalized_contact_ray, surface_ortho1)

    spin_particle_collisions := get_particle_collisions(ptcls.player_burst_particles, physics_map)
    for spc in spin_particle_collisions {
        particle := &ptcls.player_burst_particles.particles.values[spc.id]
        particle_info := &ptcls.player_burst_particles.particle_info[spc.id]
        particle.xyz -= particle_info.vel * delta_time
        particle_info.vel -= la.dot(spc.normal, particle_info.vel) * spc.normal * 1.5
    }

    if triggers.bunny_hop || triggers.small_hop {
        particle_count := triggers.small_hop ? 200 : 1500
        for idx in 0..<particle_count {
            spawn_angle := rnd.float32() * math.PI * 2.0
            spawn_vector := (math.sin(spawn_angle) * surface_ortho1 + math.cos(spawn_angle) * surface_ortho2 - normalized_contact_ray * (rnd.float32() * 0.5 + 0.25)) * 2.5
            particle_info: Particle_Info = {
                spawn_vector * 50.0 * rnd.float32() + 0.2,
                1.2,
                f32(elapsed_time),
                (rnd.float32() * 800) + 3000
            }
            spawn_pos := pls.position + la.normalize0([3]f32{spawn_vector.x, 0.1, spawn_vector.z}) * 0.5
            ptcls.player_burst_particles.particle_info[ptcls.player_burst_particles.particles.insert_at] = particle_info
            ring_buffer_push(&ptcls.player_burst_particles.particles, Particle{spawn_pos.x, spawn_pos.y, spawn_pos.z, 0})
        }
    }

    particle_count := ptcls.player_burst_particles.particles.len
    if particle_count > 0 {
        pp := ptcls.player_burst_particles.particles.values[:particle_count]
        pi := ptcls.player_burst_particles.particle_info[:particle_count]
        for p_idx in 0..<particle_count {
            pp[p_idx].xyz += pi[p_idx].vel * delta_time
            part := pi[p_idx] 
            pi[p_idx].vel += {0, -75, 0 } * delta_time
            sz_fact := clamp((f32(elapsed_time) - part.time) / part.len, 0, 1)
            pp[p_idx].w = part.max_size * (1.0 - sz_fact * sz_fact * sz_fact)
        }
        sorted_pp := make([][4]f32, particle_count, context.temp_allocator)
        copy_slice(sorted_pp, pp)

        buffer_size: i32
        gl.BindBuffer(gl.COPY_READ_BUFFER, bs.trail_particle_vbo)
        gl.GetBufferParameteriv(gl.COPY_READ_BUFFER, gl.BUFFER_SIZE, &buffer_size)
        gl.BindBuffer(gl.COPY_WRITE_BUFFER, bs.prev_trail_particle_vbo)
        gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, 0, 0, int(buffer_size))
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.trail_particle_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(sorted_pp[0]) * particle_count, &sorted_pp[0])

        particle_velocities := ptcls.player_burst_particles.particle_info.vel
        gl.BindBuffer(gl.COPY_READ_BUFFER, bs.trail_particle_velocity_vbo)
        gl.GetBufferParameteriv(gl.COPY_READ_BUFFER, gl.BUFFER_SIZE, &buffer_size)
        gl.BindBuffer(gl.COPY_WRITE_BUFFER, bs.prev_trail_particle_velocity_vbo)
        gl.CopyBufferSubData(gl.COPY_READ_BUFFER, gl.COPY_WRITE_BUFFER, 0, 0, int(buffer_size))
        gl.BindBuffer(gl.ARRAY_BUFFER, bs.trail_particle_velocity_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(particle_velocities[0]) * particle_count, &particle_velocities[0])
    }
}
