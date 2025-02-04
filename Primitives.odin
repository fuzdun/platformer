package main
import glm "core:math/linalg/glsl"
import "core:math"
import "core:fmt"

Vertex :: struct{
    pos: glm.vec4,
    uv: glm.vec2
}

IndicesList :: struct{
    shader: ProgramName,
    indices: []u16
}

ShapeData :: struct{
    vertices: []Vertex,
    indices_lists: []IndicesList,
}

SPHERE_RADIUS :: 0.5
SPHERE_SECTOR_COUNT :: 21
SPHERE_STACK_COUNT :: 20 
SPHERE_V_COUNT :: (SPHERE_STACK_COUNT + 1) * (SPHERE_SECTOR_COUNT + 1)
SPHERE_I_COUNT :: (SPHERE_STACK_COUNT - 1) * SPHERE_SECTOR_COUNT * 6 

add_sphere_data :: proc() {
    vertical_count := SPHERE_STACK_COUNT
    horizontal_count := SPHERE_SECTOR_COUNT
    x, y, z, xz: f32
    horizontal_angle, vertical_angle: f32
    s, t: f32
    vr1, vr2: u16
    PI := f32(math.PI)

    vertical_step := PI / f32(vertical_count)
    horizontal_step := (2 * PI) / f32(horizontal_count)

    vertices := &SHAPE_DATA[.Sphere].vertices
    for i in 0..=vertical_count {
        vertical_angle = PI / 2.0 - f32(i) * vertical_step 
        xz := SPHERE_RADIUS * math.cos(vertical_angle)
        y = SPHERE_RADIUS * math.sin(vertical_angle)

        for j in 0..=horizontal_count {
            v : Vertex
            horizontal_angle = f32(j) * horizontal_step 
            x = xz * math.cos(horizontal_angle)
            z = xz * math.sin(horizontal_angle)
            v.pos = {x, y, z, 1.0}
            v.uv = {f32(j) / f32(horizontal_count), f32(i) / f32(vertical_count)}
            vertices[(horizontal_count + 1) * i + j] = v
        }
    }

    ind := 0
    indices := &SHAPE_DATA[.Sphere].indices_lists[0].indices
    for i in 0..<vertical_count {
        vr1 = u16(i) * u16(horizontal_count + 1) 
        vr2 = vr1 + u16(horizontal_count) + 1

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

SHAPE_DATA := #partial [Shape]ShapeData{
    .Triangle = {
        {
            {{-0.5, -0.5, 0, 1}, {0, 0}},
            {{0.5, -0.5, 0, 1}, {1, 0}},
            {{0, 0.5, 0, 1}, {0.5, 1}}
        },
        {
            {
                .Pattern,
                {0, 1, 2}
            },
            {
                .Outline,
                {0, 1, 2}
            }
        },
    },
    .InvertedPyramid = {
        {
            {{-0.25, 0.25, 0.25, 1}, {0, 0}},
            {{0, -0.25, 0, 1},        {.5, .5}},
            {{0.25, 0.25, 0.25, 1},  {0, 1}},
            {{0.25, 0.25, -0.25, 1},   {1, 1}},
            {{-0.25, 0.25, -0.25, 1},  {1, 0}},
        },
        {
            {
                .Pattern,
                {
                    0, 1, 2,
                    2, 1, 3,
                    3, 1, 4,
                    4, 1, 0,
                    0, 2, 4,
                    2, 3, 4
                }

            },
            {
                .New,
                {
                    0, 1, 2,
                    2, 1, 3,
                    3, 1, 4,
                    4, 1, 0,
                    0, 2, 4,
                    2, 3, 4
                }

            },
            {
                .Outline,
                {
                    0, 1, 2,
                    2, 1, 3,
                    3, 1, 4,
                    4, 1, 0,
                    0, 2, 4,
                    2, 3, 4
                }
            }
        }
    },
    .Cube = {
        {
            {{-0.25, 0.25, 0.25, 1}, {0, 0}},
            {{-0.25, -0.25, 0.25, 1}, {0, 1}},
            {{0.25, -0.25, 0.25, 1}, {1, 1}},
            {{0.25, 0.25, 0.25, 1}, {1, 0}},
            {{-0.25, 0.25, -0.25, 1}, {1, 0}},
            {{-0.25, -0.25, -0.25, 1}, {0, 0}},
            {{0.25, -0.25, -0.25, 1}, {0, 1}},
            {{0.25, 0.25, -0.25, 1}, {1, 1}},
        },
        {
            {
                .Outline,
                {
                    0, 1, 2,
                    0, 2, 3,
                    3, 2, 6,
                    3, 6, 7,
                    4, 6, 5,
                    4, 7, 6,
                    4, 5, 1,
                    4, 1, 0,
                    0, 3, 4,
                    7, 4, 3,
                    1, 5, 6,
                    1, 6, 2
                }
            },
            {
                .Pattern,
                {
                    0, 1, 2,
                    0, 2, 3,
                    3, 2, 6,
                    3, 6, 7,
                    4, 6, 5,
                    4, 7, 6,
                    4, 5, 1,
                    4, 1, 0,
                    0, 3, 4,
                    7, 4, 3,
                    1, 5, 6,
                    1, 6, 2
                }
            },
            {
                .New,
                {
                    0, 1, 2,
                    0, 2, 3,
                    3, 2, 6,
                    3, 6, 7,
                    4, 5, 6,
                    4, 6, 7,
                    4, 5, 1,
                    4, 1, 0,
                    0, 3, 4,
                    7, 4, 3,
                    1, 5, 6,
                    1, 6, 2
                }
            }
        }
    },
    .Sphere = {
        make([]Vertex, SPHERE_V_COUNT),
        {
            {
                .Player,
                make([]u16, SPHERE_I_COUNT)
            }
        }
    },
    .Plane = {
        {
            {{-1, 0, -1, 1}, {0, 0}},
            {{-1, 0, 1, 1},{0, 1}},
            {{1, 0, 1, 1},{1, 1}},
            {{1, 0, -1, 1},{1, 0}}
        },
        {
            {
                .Reactive,
                {
                    0, 1, 3,
                    3, 1, 2 
                }
            },
            {
                .Trail,
                {
                    0, 1, 3,
                    3, 1, 2 
                }
            }
        }
    }
}

