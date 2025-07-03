package state

import enm "../enums"
import typ "../datatypes"

Level_Resources :: [enm.SHAPE]typ.Shape_Data

free_level_resources :: proc(lr: ^Level_Resources) {
    for sd in lr {
        delete(sd.indices) 
        delete(sd.vertices)
    }
}

