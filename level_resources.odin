package main

Level_Resources :: [SHAPE]Shape_Data

free_level_resources :: proc(lr: ^Level_Resources) {
    for sd in lr {
        delete(sd.indices) 
        delete(sd.vertices)
    }
}

