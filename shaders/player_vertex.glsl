#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

out vec2 uv;
out float time;

#define PI 3.1415

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std140, binding = 1) uniform Dash
{
    float dash_time;
    float dash_total;
    vec3 constrain_dir;
};

uniform mat4 transform;


float easeout(float n) {
    return sin(n * PI / 2.0);
}

void main() {
    vec3 constrain_proj = constrain_dir * dot(constrain_dir, aPos.xyz);
    vec3 constrained_pos = aPos.xyz - constrain_proj;

    float dash_pos_t = length(constrain_dir - constrain_proj) / 2.0;
    float constrain_start_t = dash_time + 50.0 * dash_pos_t;
    float constrain_amt = 1.0 - easeout(clamp((i_time - constrain_start_t) / 300.0, 0.0, 1.0));
    if (i_time - dash_time > 200) {
        constrain_amt = 1.0;
    }
    constrained_pos *= constrain_amt;
    constrained_pos += constrain_proj;
    constrained_pos += constrain_proj * (1.0 - constrain_amt) * 2.5 + constrain_dir * 2.5 * (1.0 - constrain_amt);
    // gl_Position = projection * offset_mat * transform * vec4(constrained_pos, aPos.w);
    gl_Position = projection * transform * vec4(constrained_pos, aPos.w);
    uv = vertexUV;
    time = i_time;
}
