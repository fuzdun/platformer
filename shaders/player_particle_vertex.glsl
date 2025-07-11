#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;
layout (location = 2) in vec4 offset;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 1) uniform Dash
{
    float dash_time;
    float dash_end_time;
    vec3 constrain_dir;
};

layout (std140, binding = 2) uniform Player_Pos
{
    vec3 player_pos;
};

uniform float radius;

out vec2 uv;
out float f_radius; 
out float i_time_frag;
flat out int id;

#define PI 3.1415


float easeout(float n) {
    return sin(n * PI / 2.0);
}

void main() {
    // vec4 adjusted_offset = offset + vec4(player_pos, 0.0) * 2.0;
    vec3 constrain_proj = constrain_dir * dot(constrain_dir, offset.xyz);
    vec3 constrained_pos = offset.xyz - constrain_proj;
    float dash_pos_t = length(constrain_dir - constrain_proj) / 2.0;
    float constrain_start_t = dash_time + 50.0 * dash_pos_t;
    float constrain_amt = 1.0 - easeout(clamp((i_time - constrain_start_t) / 75.0, 0.0, 1.0));
    if (i_time - dash_time > 200) {
        constrain_amt = 1.0;
    }
    f_radius = radius * constrain_amt;

    vec3 stretched_offset = offset.xyz + constrain_proj * (1.0 - constrain_amt) * 2.5 + constrain_dir * 2.5 * (1.0 - constrain_amt);

    id = int(offset.a);
    uv = uv_in;
    i_time_frag = i_time;
    gl_Position = projection * (aPos + vec4(stretched_offset.xyz, 1.0) + vec4(player_pos, 0.0) * 2.0);
}

