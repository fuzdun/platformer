package datatypes

Collision :: struct{
    id: int,
    normal: [3]f32,
    plane_dist: f32,
    contact_dist: f32,
    t: f32
}

Collider_Data :: struct{
    vertices: [][3]f32,
    indices: []u16
}

