package datatypes

model_json_struct :: struct {
    bufferViews: []struct {
        byteOffset: int,
        byteLength: int
    },
    scenes: []struct {
        nodes: []int
    },
    meshes: []struct {
        primitives: []struct {
            indices: int,
            attributes: map[string]int
        }
    }
}

free_model_json_struct :: proc(js: model_json_struct) {
    for m in js.meshes {
        for p in m.primitives {
            for k, _ in p.attributes {
                delete(k)
            }
            delete(p.attributes)
        } 
        delete(m.primitives)
    }
    for s in js.scenes {
        delete(s.nodes)
    }
    delete(js.scenes)
    delete(js.bufferViews)
    delete(js.meshes)
}
