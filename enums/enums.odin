package enums

SHAPE :: enum{
    CUBE,
    WEIRD,
}

ProgramName :: enum{
    Player,
    Trail,
    Simple,
    Background,
    Player_Particle,
    Outline,
    Text,
    Line
}

Level_Geometry_Component_Name :: enum {
    Transform = 0,
    Shape = 1,
    Collider = 2,
    Active_Shaders = 3,
    Angular_Velocity = 4 
}

Player_States :: enum {
    ON_GROUND,
    ON_WALL,
    ON_SLOPE,
    IN_AIR,
    DASHING 
}

