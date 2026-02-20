#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	vec2 _padding0;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir_in;
    float inner_tess;
    float outer_tess;
};

layout (std140, binding = 4) buffer Transforms
{
    mat4 transforms[1000]; 
};

layout (std140, binding = 5) buffer Z_Widths
{
    float z_width_data[1000]; 
};

struct Break_Data {
    vec4 break_time_pos;
    vec4 crack_time_break_dir;
};

layout (std140, binding = 6) buffer Shatter_Datas
{
    Break_Data break_data[1000]; 
};

out VS_OUT {
    vec2 uv;
    vec4 obj_pos;
    flat int cracked;
    flat int broken;
    float player_dist;
    float tess_amt;
} vs_out;

out vec2 uv;
out float player_dist;
out flat int cracked;

void main() {
    mat4 transform = transforms[gl_BaseInstance + gl_InstanceID];
    vec4 new_pos = transform * aPos;
    // float player_dist = max(0, player_pos.z - (z_width_data[gl_BaseInstance + gl_InstanceID]) - 40 - new_pos.z);;
    float player_dist = distance(player_pos, new_pos.xyz) - 200;
    // vec2 projected_point = (projection * new_pos).xy;
    // vec2 projected_disp = projected_point - 0.5;
    // new_pos.xy -= (player_dist / 50.0) * projected_disp;
    // new_pos = mix(vec4(0), new_pos, 0.5);
    Break_Data bd = break_data[gl_BaseInstance + gl_InstanceID];
    float break_time = bd.break_time_pos.x;
    float crack_time = bd.crack_time_break_dir.x;
    vs_out.cracked = (crack_time != 0 && i_time > crack_time) ? 1 : 0;
    vs_out.broken = (break_time != 0 && i_time > break_time) ? 1 : 0;
    vs_out.obj_pos = vec4(transform[3][0], transform[3][1], transform[3][2], 1.0);
    vs_out.player_dist = player_dist;
    gl_Position = new_pos;
    vs_out.uv = vertexUV;
    vs_out.tess_amt = 12;
}

