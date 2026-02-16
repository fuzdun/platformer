#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

layout (std140, binding = 3) uniform Tessellation
{
    float inner_amt;
    float outer_amt;
};

layout (std140, binding = 4) uniform Transforms
{
    mat4 transforms[1000]; 
};

layout (std140, binding = 5) uniform Z_Widths
{
    float z_width_data[1000]; 
};

struct Break_Data {
    vec4 break_time_pos;
    vec4 crack_time_break_dir;
};

layout (std140, binding = 6) uniform Shatter_Datas
{
    Break_Data break_data[1000]; 
};

out VS_OUT {
    float id;
    vec2 uv;
    vec3 normal_frag;
    vec4 obj_pos;
    float player_dist;
    float plane_dist;
    vec4 break_time_pos;
    vec4 crack_time_break_dir;
    float outer_tess_amt;
    float inner_tess_amt;
} vs_out;


void main() {
    vs_out.id = gl_BaseInstance + gl_InstanceID + 1; 
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    vec4 new_pos = transform * aPos;
    float player_dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 40 - new_pos.z);;
    vec2 projected_point = (projection * new_pos).xy;
    vec2 projected_disp = projected_point - 0.5;
    new_pos.xy -= (player_dist / 50.0) * projected_disp;
    gl_Position = new_pos;
    vec3 rot_normal = normalize(mat3(transpose(inverse(transform))) * normal_in).xyz;

    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.uv = vertexUV;
    vs_out.normal_frag = rot_normal;
    vs_out.player_dist = player_dist;
    vs_out.plane_dist = dot((transform * aPos).xyz, rot_normal);
    Break_Data bd = break_data[gl_BaseInstance + gl_InstanceID];
    vs_out.break_time_pos = bd.break_time_pos; 
    vs_out.crack_time_break_dir = bd.crack_time_break_dir;
    vs_out.outer_tess_amt = outer_amt;
    vs_out.inner_tess_amt = inner_amt;
}

