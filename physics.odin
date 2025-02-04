package main
import la "core:math/linalg"
import "core:fmt"

//AABB_INDICES :: []u16 {0, 1, 2, 0, 2, 3, 3, 2, 6, 3, 6, 7, 4, 5, 6, 4, 6, 7, 4, 5, 1, 4, 1, 0, 0, 3, 4, 7, 4, 3, 1, 5, 6, 1, 6, 2}
AABB_INDICES :: []u16 {
  0, 1,
  0, 3,
  1, 2,
  2, 3,
  3, 7,
  2, 6,
  4, 5,
  4, 7,
  6, 7,
  6, 5,
  4, 0,
  5, 1
}

Physics_State :: struct {
    vertices: [dynamic][3]f32,
    objects: [dynamic]Physics_Object,
}

Physics_Object :: struct {
    id: int,
    indices: [dynamic]u16,
    aabbx0: f32,
    aabby0: f32,
    aabbz0: f32,
    aabbx1: f32,
    aabby1: f32,
    aabbz1: f32,
    collided: bool
}

init_physics_state :: proc(ps: ^Physics_State) {
    ps.vertices = make([dynamic][3]f32)
    ps.objects = make([dynamic]Physics_Object)
}

clear_physics_state :: proc(ps: ^Physics_State) {
    for &obj in ps.objects {
        clear(&obj.indices)
    }
    clear(&ps.objects)
    clear(&ps.vertices)
}

free_physics_state :: proc(ps: ^Physics_State) {
    for obj in ps.objects {
        delete(obj.indices)
    }
    delete(ps.vertices)
    delete(ps.objects)
}

construct_aabbs :: proc(gs: ^GameState, phys_s: ^Physics_State) {
    clear_physics_state(phys_s)

    filter : bit_set[Level_Geometry_Component_Name] = { .Colliding, .Position, .Shape }

    for lg, id in gs.level_geometry {
        if filter <= lg.attributes {
            indices_offset := u16(len(phys_s.vertices))

            po : Physics_Object
            po.id = id
            po.indices = make([dynamic]u16)
            po.aabbx0, po.aabby0, po.aabbz0 = max(f32), max(f32), max(f32)
            po.aabbx1, po.aabby1, po.aabbz1 = min(f32), min(f32), min(f32)

            sd := SHAPE_DATA[lg.shape]
            for v, idx in sd.vertices {
                new_pos := la.quaternion128_mul_vector3(lg.rotation, v.pos.xyz * lg.scale) + lg.position
                po.aabbx0 = min(new_pos.x, po.aabbx0)
                po.aabby0 = min(new_pos.y, po.aabby0)
                po.aabbz0 = min(new_pos.z, po.aabbz0)
                po.aabbx1 = max(new_pos.x, po.aabbx1)
                po.aabby1 = max(new_pos.y, po.aabby1)
                po.aabbz1 = max(new_pos.z, po.aabbz1)
                append(&phys_s.vertices, new_pos)
            }
            for il in sd.indices_lists {
                if il.shader == .Outline {
                    offset_indices(il.indices, indices_offset, &po.indices)
                }
            }
            append(&phys_s.objects, po)
        }
    }
    ppos := gs.player_state.position
    px, py, pz := f32(ppos[0]), f32(ppos[1]), f32(ppos[2])
    player_sq_radius := f32(SPHERE_RADIUS * SPHERE_RADIUS)
    for &po in phys_s.objects {
        total : f32 = 0
        if px < po.aabbx0 do total += (px - po.aabbx0) * (px - po.aabbx0)
        if px > po.aabbx1 do total += (px - po.aabbx1) * (px - po.aabbx1)
        if py < po.aabby0 do total += (py - po.aabby0) * (py - po.aabby0)
        if py > po.aabby1 do total += (py - po.aabby1) * (py - po.aabby1)
        if pz < po.aabbz0 do total += (pz - po.aabbz0) * (pz - po.aabbz0)
        if pz > po.aabbz1 do total += (pz - po.aabbz1) * (pz - po.aabbz1)
        if total < player_sq_radius {
            po.collided = true            
        }
    }
}

aabb_vertices :: proc(po: Physics_Object) -> [8]Vertex {
    return {
        {{po.aabbx0, po.aabby1, po.aabbz0, 1}, {0, 0}},
        {{po.aabbx0, po.aabby0, po.aabbz0, 1}, {0, 1}},
        {{po.aabbx1, po.aabby0, po.aabbz0, 1}, {1, 1}},
        {{po.aabbx1, po.aabby1, po.aabbz0, 1}, {1, 0}},

        {{po.aabbx0, po.aabby1, po.aabbz1, 1}, {1, 0}},
        {{po.aabbx0, po.aabby0, po.aabbz1, 1}, {0, 0}},
        {{po.aabbx1, po.aabby0, po.aabbz1, 1}, {0, 1}},
        {{po.aabbx1, po.aabby1, po.aabbz1, 1}, {1, 1}},
    }
}

