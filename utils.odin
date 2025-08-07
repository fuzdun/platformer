package main

dynamic_array_swap :: proc(a: ^[dynamic]$T, b: ^[dynamic]T)  {
    clear(a)   
    for val in b {
        append(a, val)
    }
    delete(b^)
}

dynamic_soa_swap :: proc(a: ^#soa[dynamic]$T, b: ^#soa[dynamic]T)  {
    clear_soa(a)   
    for val in b {
        append(a, val)
    }
    delete_soa(b^)
}

dynamic_soa_copy :: proc(a: #soa[dynamic]$T) -> #soa[dynamic]T{
    b := make(#soa[dynamic]T)
    for val in a {
        append(&b, val)
    }
    return b
}


