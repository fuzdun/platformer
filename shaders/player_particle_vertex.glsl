#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;
layout (location = 2) in vec4 offset;
layout (location = 3) in vec4 prev_offset;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	float _pad0;
	vec3 cam_pos;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir;
    float inner_tess;
    float outer_tess;
	vec4 _pad1;
};

uniform float radius;
uniform float interp_t;

out vec2 uv;
out float f_radius; 
out float i_time_frag;
flat out int id;

#define PI 3.1415


float easeout(float n) {
    return sin(n * PI / 2.0);
}

void main() {
    vec4 adjusted_offset = vec4(mix(prev_offset.xyz, offset.xyz, interp_t), 0.0);// + vec4(player_pos, 0.0);
    // vec3 velocity = vec3(offset.xyz - prev_offset.xyz);
    // adjusted_offset.xyz += velocity * max(0, dot(velocity, aPos.xyz)) * 10.0;
    // vec4 adjusted_offset = vec4(offset.xyz, 0.0);// + vec4(player_pos, 0.0);
    // vec3 constrain_proj = constrain_dir * dot(constrain_dir, offset.xyz);
    // vec3 constrained_pos = offset.xyz - constrain_proj;
    // float dash_pos_t = length(constrain_dir - constrain_proj) / 2.0;
    // // float constrain_start_t = dash_time + 50.0 * dash_pos_t;
    // float constrain_start_t = 50.0 * dash_pos_t;
    // float constrain_amt = 1.0 - easeout(clamp((dash_total - constrain_start_t) / 300.0, 0.0, 1.0));
    // // if (i_time - dash_time > 200) {
    // if (dash_total > 200) {
    //     constrain_amt = 1.0;
    // }
    // f_radius = radius * constrain_amt;
    //
    // vec3 stretched_offset = offset.xyz + constrain_proj * (1.0 - constrain_amt) * 2.5 + constrain_dir * 2.5 * (1.0 - constrain_amt);
    //
    id = int(offset.a);
    uv = uv_in;
    i_time_frag = i_time;
    f_radius = radius * offset.w;
    // f_radius = radius;
    gl_Position = projection * (aPos + adjusted_offset);
    // gl_Position = projection * (aPos + vec4(stretched_offset.xyz, 1.0) + vec4(player_pos, 0.0) * 2.0);
}

