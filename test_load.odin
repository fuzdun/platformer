package main
import rnd "core:math/rand"
import glm "core:math/linalg/glsl"

load_random_shapes :: proc(gs: ^GameState, num: int) {
    for _ in 0..<num {
        obj := add_entity(&gs.ecs)
        shaders : []ProgramName = { .New, .Pattern }
        shapes : []Shape = { .Cube, .InvertedPyramid }
        shape := rnd.choice(shapes)
        shader := rnd.choice(shaders)
        active_shaders := ActiveShaders { shader }
        add_shaders(&gs.ecs, obj, active_shaders)
        add_shape(&gs.ecs, obj, shape)
        x := rnd.float32_range(-30, 30)
        y := rnd.float32_range(-30, 30)
        z := rnd.float32_range(-30, 30)
        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)
        vx := rnd.float32_range(-.2, .2)
        vy := rnd.float32_range(-.2, .2)
        vz := rnd.float32_range(-.2, .2)
        transform := glm.mat4Translate({x, y, z}) *
                     glm.mat4Scale({10, 10, 10}) *
                     glm.mat4Rotate({1, 0, 0}, rx) *
                     glm.mat4Rotate({0, 1, 0}, ry) *
                     glm.mat4Rotate({0, 0, 1}, rz)
        add_transform(&gs.ecs, obj, transform)
        if rnd.float32_range(0, 1) < 0.5 {
            add_velocity(&gs.ecs, obj, {vx, vy, vz})
        }
    }
}

load_test_floor :: proc(gs: ^GameState, w: f32, h: f32) {
    flr := add_entity(&gs.ecs)
    add_shape(&gs.ecs, flr, .Plane)
    add_transform(&gs.ecs, flr, glm.mat4Translate({0, -.5, 0}) * glm.mat4Scale({w, 0, h}))
    active_shaders := ActiveShaders { .Trail }
    add_shaders(&gs.ecs, flr, active_shaders)
}

