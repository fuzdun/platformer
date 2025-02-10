package main
import la "core:math/linalg"
import rnd "core:math/rand"

load_physics_test_box :: proc(gs: ^Game_State, w: f32, h: f32, d: f32, num: int) {
    for _ in 0..<num {
        shaders : []ProgramName = {.New, .Pattern}
        shapes : []Shape = {.Cube, .InvertedPyramid}

        x := rnd.float32_range(-200, 200)
        y := rnd.float32_range(-200, 200)
        z := rnd.float32_range(-200, 200)

        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)

        rs := rnd.float32_range(1, 100)

        box : Level_Geometry
        box.position = {x, y, z}
        box.scale = {rs, rs, rs}
        box.shaders  = {rnd.choice(shaders)}
        box.shape = rnd.choice(shapes)
        box.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
        box.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Rotation}
        if rnd.float32_range(0, 1) < 0.5 {
            vx := rnd.float32_range(-2, 2)
            vy := rnd.float32_range(-2, 2)
            vz := rnd.float32_range(-2, 2)
            box.velocity = {vx, vy, vz}
            box.attributes += {.Velocity}
        }
        append(&gs.level_geometry, box)
    }
    box : Level_Geometry
    rx, ry, rz : f32 = 0, 0, -.35 
    box.position = {0, -2, 4}
    box.scale = {40, 40, 40}
    box.shaders  = {.Reactive, .BlueOutline}
    box.shape = .Cube
    box.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
    box.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box)

    box2 : Level_Geometry
    rx2, ry2, rz2 : f32 = 0, 0, .25  
    box2.position = {40, -8, -65}
    box2.scale = {100, 100, 100}
    box2.shaders  = {.Reactive, .BlueOutline}
    box2.shape = .Cube
    box2.rotation = la.quaternion_from_euler_angles(rx2, ry2, rz2, .XYZ)
    box2.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box2)

    box3 : Level_Geometry
    rx3, ry3, rz3 : f32 = 0, 0, -.1  
    box3.position = {20, 0, -160}
    box3.scale = {100, 100, 100}
    box3.shaders  = {.Reactive, .BlueOutline}
    box3.shape = .Cube
    box3.rotation = la.quaternion_from_euler_angles(rx3, ry3, rz3, .XYZ)
    box3.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box3)
}
