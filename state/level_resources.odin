package state

import enm "../enums"

Level_Resources :: [enm.SHAPE]Shape_Data

free_level_resources :: proc(lr: ^Level_Resources) {
    for sd in lr {
        delete(sd.indices) 
        delete(sd.vertices)
    }
}

Shape_Data :: struct{
    vertices: []Vertex,
    indices: []u32
}

