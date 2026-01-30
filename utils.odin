package main

dynamic_array_swap :: proc(a: ^[dynamic]$T, b: [dynamic]T)  {
    delete(a^)
    a^ = b
}

dynamic_soa_swap :: proc(a: ^#soa[dynamic]$T, b: #soa[dynamic]T)  {
    delete_soa(a^)
    a^ = b
}

dynamic_soa_copy :: proc(a: #soa[dynamic]$T) -> #soa[dynamic]T{
    b := make(#soa[dynamic]T)
    for val in a {
        append(&b, val)
    }
    return b
}

soa_swap :: proc(a: ^#soa[]$T, b: #soa[]T)  {
    delete_soa(a^)
    a^ = b
}

soa_copy :: proc(a: #soa[]$T) -> #soa[]T{
    b := make(#soa[]T, len(a))
    for val, i in a {
        b[i] = val
    }
    return b
}

set_swap :: proc(a: ^map[$T]struct{}, b: map[T]struct{}) {
    delete(a^)
    a^= b
}

