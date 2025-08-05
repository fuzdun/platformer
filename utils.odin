package main

dynamic_array_swap :: proc(a: ^[dynamic]$T, b: ^[dynamic]T)  {
    clear(a)   
    for val in b {
        append(a, val)
    }
    delete(b^)
}

