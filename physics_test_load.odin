package main
import la "core:math/linalg"
import rnd "core:math/rand"

load_physics_test_box :: proc(gs: ^Game_State, w: f32, h: f32, d: f32, num: int) {
    for _ in 0..<num {
        shaders : []ProgramName = {.New, .Pattern}
        shapes : []Shape = {.Cube, .InvertedPyramid}

        x := rnd.float32_range(-30, 30)
        y := rnd.float32_range(-30, 30)
        z := rnd.float32_range(-30, 30)

        rx := rnd.float32_range(-180, 180)
        ry := rnd.float32_range(-180, 180)
        rz := rnd.float32_range(-180, 180)

        box : Level_Geometry
        box.position = {x, y, z}
        box.scale = {w, h, d}
        box.shaders  = {rnd.choice(shaders)}
        box.shape = rnd.choice(shapes)
        box.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
        box.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
        if rnd.float32_range(0, 1) < 0.5 {
            vx := rnd.float32_range(-2, 2)
            vy := rnd.float32_range(-2, 2)
            vz := rnd.float32_range(-2, 2)
            box.velocity = {vx, vy, vz}
            box.attributes += {.Velocity}
        }
        append(&gs.level_geometry, box)
    }
    //flr : Level_Geometry
    //flr.shape = .Plane
    //flr.position = {0, -.5, 0}
    //rx:f32 = 0
    //ry:f32 = 0
    //rz:f32 = 0
    //flr.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
    //flr.scale = {100, 0, 100}
    //flr.shaders = {.Trail}
    //flr.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Rotation}
    //append(&gs.level_geometry, flr)
        //box : Level_Geometry
        //rx, ry, rz : f32 = 0, 0, 0
        //box.position = {0, 0, -10}
        //box.scale = {10, 10, 10}
        //box.shaders  = {.New}
        //box.shape = .Cube
        //box.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
        //box.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
        //append(&gs.level_geometry, box)
}

//load_random_shapes :: proc(gs: ^Game_State, num: int) {
//    for _ in 0..<num {
//
//
//        lg : Level_Geometry
//        lg.position = {x, y, z}
//        lg.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
//        lg.scale = {10, 10, 10}
//        lg.attributes = {.ActiveShaders, .Position, .Scale, .Shape}
//        if rnd.float32_range(0, 1) < 0.5 {
//            vx := rnd.float32_range(-2, 2)
//            vy := rnd.float32_range(-2, 2)
//            vz := rnd.float32_range(-2, 2)
//            lg.velocity = {vx, vy, vz}
//            lg.attributes += {.Velocity}
//        }
//        append(&gs.level_geometry, lg)
//    }
//}
