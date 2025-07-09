package main

Shape_Resources :: [SHAPE]Shape_Data

free_level_resources :: proc(sr: ^Shape_Resources) {
    for sd in sr {
        delete(sd.indices) 
        delete(sd.vertices)
    }
}

