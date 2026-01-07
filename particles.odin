package main

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

particle_buffer_init :: proc(pb: ^$T/Particle_Buffer) {
    ring_buffer_init(&pb.particles, Particle{})
    pb.particle_info = make(#soa[]Particle_Info, pb.particles.cap)
}
