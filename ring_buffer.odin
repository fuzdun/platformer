package main


RingBuffer :: struct($N: int, $T: typeid) {
    len: int,
    cap: int,
    insert_at: int,
    values: [N]T
}

ring_buffer_init :: proc(buffer: ^RingBuffer($N, $T), default: T) {
    buffer.cap = N
    for &v in buffer.values {
        v = default
    }
}

ring_buffer_push :: proc(buffer: ^RingBuffer($N, $T), value: T) {
    buffer.values[buffer.insert_at] = value
    buffer.len = max(buffer.len, buffer.insert_at + 1)
    buffer.insert_at = (buffer.insert_at + 1) % N
}

ring_buffer_average :: proc(buffer: RingBuffer($N, $T)) -> T {
    sum : T = 0
    for val in buffer.values {
        sum += val
    }
    return sum / T(N)
}

ring_buffer_at :: proc(buffer: RingBuffer($N, $T), idx: int) -> T {
    adjusted_idx := buffer.insert_at + idx
    if adjusted_idx < 0 {
        adjusted_idx += N
    }
    return buffer.values[adjusted_idx % N]
}

ring_buffer_copy :: proc(buffer: RingBuffer($N, $T)) -> RingBuffer(N, T) {
    new_ring_buffer: RingBuffer(N, T) 
    new_ring_buffer.values = buffer.values
    new_ring_buffer.insert_at = buffer.insert_at
    return new_ring_buffer
}

