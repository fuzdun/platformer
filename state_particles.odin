package main

import "base:runtime"

Particle_State :: struct {
    player_burst_particles: Particle_Buffer(PLAYER_SPIN_PARTICLE_COUNT),
}

Particle :: [4]f32 // vec3 pos, f32 size
Particle_Info :: struct #packed {
    vel: [3]f32,
    max_size: f32,
    time: f32,
    len: f32
}

Particle_Buffer :: struct($N: int) {
    particles: RingBuffer(N, Particle),
    particle_info: #soa[]Particle_Info
}


particle_buffer_init :: proc(pb: ^$T/Particle_Buffer, alloc: runtime.Allocator) {
    ring_buffer_init(&pb.particles, Particle{}, alloc)
    pb.particle_info = make(#soa[]Particle_Info, pb.particles.cap, alloc)
}

particle_buffer_copy :: proc(pb: Particle_Buffer($N), alloc: runtime.Allocator) -> (new_pb: Particle_Buffer(N)) {
    //ring_buffer_init(&new_pb.particles, Particle{}, alloc)
    new_pb.particles = ring_buffer_copy(pb.particles)
    new_pb.particle_info = soa_copy(pb.particle_info)
    return
}

particle_buffer_swap :: proc(a: ^Particle_Buffer($N), b: Particle_Buffer(N)) {
    particle_buffer_free(a^)
    a^ = b
}

particle_buffer_free :: proc(pb: Particle_Buffer($N)) {
    ring_buffer_free(pb.particles) 
    delete(pb.particle_info)
}

