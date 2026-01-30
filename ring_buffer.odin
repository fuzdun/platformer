package main

import "base:runtime"
import "core:fmt"

RingBuffer :: struct($N: int, $T: typeid) {
    len: int,
    cap: int,
    insert_at: int,
    values: ^[N]T
}

ring_buffer_init :: proc(buffer: ^RingBuffer($N, $T), default: T, alloc: runtime.Allocator) {
    buffer.cap = N
    buffer.values = new([N]T, alloc)
    for &v in buffer.values {
        v = default
    }
}

ring_buffer_free :: proc(buffer: RingBuffer($N, $T)) {
    free(buffer.values)
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

ring_buffer_copy :: proc(buffer: RingBuffer($N, $T)) -> (new_rb: RingBuffer(N, T)) {
    ring_buffer_init(&new_rb, T{}, context.allocator)
    copy(new_rb.values[:], buffer.values[:])
    new_rb.insert_at = buffer.insert_at
    new_rb.len = buffer.len
    new_rb.cap = buffer.cap
    return new_rb
}

ring_buffer_swap :: proc(a: ^RingBuffer($N, $T), b: RingBuffer(N, T)) {
    ring_buffer_free(a^)
    a^ = b
}

