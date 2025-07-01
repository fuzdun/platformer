package main
import glm "core:math/linalg/glsl"
import "core:math"
import "core:fmt"
import enm "state/enums"

Vertex :: struct{
    pos: glm.vec3,
    uv: glm.vec2,
    b_uv: glm.vec2,
    normal: glm.vec3
}

Particle_Vertex :: struct{
    pos: glm.vec4,
    uv: glm.vec2
}

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


Collider_Data :: struct{
    vertices: [][3]f32,
    indices: []u16
}

// CORE_RADIUS :: 0.5
CORE_RADIUS :: 1.0
SPHERE_RADIUS :: 1.0
SPHERE_SQ_RADIUS :: SPHERE_RADIUS * SPHERE_RADIUS
SPHERE_SECTOR_COUNT :: 30 
SPHERE_STACK_COUNT :: 30 
SPHERE_V_COUNT :: (SPHERE_STACK_COUNT + 1) * (SPHERE_SECTOR_COUNT + 1)
SPHERE_I_COUNT :: (SPHERE_STACK_COUNT - 1) * SPHERE_SECTOR_COUNT * 6 

add_player_sphere_data :: proc(rs: ^Render_State) {
    vertical_count := SPHERE_STACK_COUNT
    horizontal_count := SPHERE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u32
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count)
    horizontal_step := (2 * PI) / f32(horizontal_count)

    rs.player_geometry.vertices = make([]Vertex, SPHERE_V_COUNT)
    vertices := &rs.player_geometry.vertices
    for i in 0..=vertical_count {
        vertical_angle = PI / 2.0 - f32(i) * vertical_step 
        xz := CORE_RADIUS * math.cos(vertical_angle)
        y = CORE_RADIUS * math.sin(vertical_angle)

        for j in 0..=horizontal_count {
            v : Vertex
            horizontal_angle = f32(j) * horizontal_step 
            x = xz * math.cos(horizontal_angle)
            z = xz * math.sin(horizontal_angle)
            v.pos = {x, y, z}
            uv: glm.vec2 = {f32(j) / f32(horizontal_count), f32(i) / f32(vertical_count)}
            v.uv = uv
            v.b_uv = uv
            vertices[(horizontal_count + 1) * i + j] = v
        }
    }

    ind := 0
    rs.player_geometry.indices = make([]u32, SPHERE_I_COUNT)
    indices := &rs.player_geometry.indices
    for i in 0..<vertical_count {
        vr1 = u32(i * (horizontal_count + 1))
        vr2 = vr1 + u32(horizontal_count) + 1

        for j := 0; j < horizontal_count; {
            if i != 0 {
                indices[ind] = vr1
                indices[ind+1] = vr2
                indices[ind+2] = vr1+1
                ind += 3
            }
            if i != vertical_count - 1 {
                indices[ind] = vr1 + 1
                indices[ind+1] = vr2
                indices[ind+2] = vr2 + 1
                ind += 3
            }
            //append(&outline_indices, vr1, vr2)
            if i != 0 {
                //append(&outline_indices, vr1, vr1 + 1)
            }
            j += 1 
            vr1 += 1
            vr2 += 1
        }
    }
}

