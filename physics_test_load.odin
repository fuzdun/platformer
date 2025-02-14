package main
import la "core:math/linalg"
import rnd "core:math/rand"

load_physics_test_box :: proc(gs: ^Game_State, w: f32, h: f32, d: f32, num: int) {
    for _ in 0..<num {
        shaders : []ProgramName = {.Pattern, .New}
        shapes : []Shape = {.Cube, .InvertedPyramid}

        x := rnd.float32_range(-300, 300)
        y := rnd.float32_range(-50, 300)
        z := rnd.float32_range(-700, 200)

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
    box.scale = {10, 10, 10}
    box.shaders  = {.Trail, .RedOutline}
    box.shape = .Cube
    box.shape_string = "cube"
    box.rotation = la.quaternion_from_euler_angles(rx, ry, rz, .XYZ)
    box.attributes = {.Position, .Shape, .ShapeString, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box)

    box2 : Level_Geometry
    rx2, ry2, rz2 : f32 = 0, 0, .25  
    box2.position = {40, -8, -65}
    box2.scale = {100, 100, 100}
    box2.shaders  = {.Trail, .RedOutline}
    box2.shape = .Cube
    box2.rotation = la.quaternion_from_euler_angles(rx2, ry2, rz2, .XYZ)
    box2.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box2)

    box3 : Level_Geometry
    rx3, ry3, rz3 : f32 = 0, 0, -.1  
    box3.position = {20, 0, -150}
    box3.scale = {100, 100, 100}
    box3.shaders  = {.Trail, .RedOutline}
    box3.shape = .Cube
    box3.rotation = la.quaternion_from_euler_angles(rx3, ry3, rz3, .XYZ)
    box3.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box3)

    box4 : Level_Geometry
    rx4, ry4, rz4 : f32 = 0, 0, 0  
    box4.position = {70, 20, -220}
    box4.scale = {30, 30, 30}
    box4.shaders  = {.Trail, .RedOutline}
    box4.shape = .Cube
    box4.rotation = la.quaternion_from_euler_angles(rx4, ry4, rz4, .XYZ)
    box4.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box4)

    box5 : Level_Geometry
    rx5, ry5, rz5 : f32 = 0, 0, 0  
    box5.position = {30, 25, -260}
    box5.scale = {35, 35, 35}
    box5.shaders  = {.Trail, .RedOutline}
    box5.shape = .Cube
    box5.rotation = la.quaternion_from_euler_angles(rx5, ry5, rz5, .XYZ)
    box5.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box5)

    box6 : Level_Geometry
    rx6, ry6, rz6 : f32 = -1.8, 0, 0  
    box6.position = {30, 20, -350}
    box6.scale = {100, 100, 100}
    box6.shaders  = {.Trail, .RedOutline}
    box6.shape = .InvertedPyramid
    box6.rotation = la.quaternion_from_euler_angles(rx6, ry6, rz6, .XYZ)
    box6.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box6)

    box7 : Level_Geometry
    rx7, ry7, rz7 : f32 = 0, 0, 0  
    box7.position = {25, 10, -485}
    box7.scale = {40, 40, 100}
    box7.shaders  = {.Trail, .RedOutline}
    box7.shape = .Cube
    box7.rotation = la.quaternion_from_euler_angles(rx7, ry7, rz7, .XYZ)
    box7.attributes = {.Position, .Shape, .ActiveShaders, .Scale, .Colliding, .Rotation}
    append(&gs.level_geometry, box7)
}
