package main
import rnd "core:math/rand"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

load_random_shapes :: proc(gs: ^Game_State, num: int) {
    for _ in 0..<num {
        shaders : []ProgramName = {.New, .Pattern}
        shapes : []Shape = {.Cube, .InvertedPyramid}

        x := rnd.float32_range(-30, 30)
        y := rnd.float32_range(-30, 30)
        z := rnd.float32_range(-30, 30)

        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)

        lg : Level_Geometry
        lg.shaders  = {rnd.choice(shaders)}
        lg.shape = rnd.choice(shapes)
        lg.position = {x, y, z}
        lg.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
        lg.scale = {10, 10, 10}
        lg.attributes = {.ActiveShaders, .Position, .Scale, .Shape}
        if rnd.float32_range(0, 1) < 0.5 {
            vx := rnd.float32_range(-2, 2)
            vy := rnd.float32_range(-2, 2)
            vz := rnd.float32_range(-2, 2)
            lg.velocity = {vx, vy, vz}
            lg.attributes += {.Velocity}
        }
        append(&gs.level_geometry, lg)
    }
}

load_test_floor :: proc(gs: ^Game_State, w: f32, h: f32) {
    flr : Level_Geometry
    flr.shape = .Plane
    flr.position = {0, -.5, 0}
    flr.scale = {w, 1, h}
    flr.shaders = {.Trail}
    flr.attributes = {.Position, .Shape, .ActiveShaders, .Scale}
    append(&gs.level_geometry, flr)
}

