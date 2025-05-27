#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

out vec2 uv;
out float time;

uniform float i_time;
uniform mat4 projection;
uniform mat4 transform;
uniform float constrain_amt;
uniform vec3 constrain_dir;

void main() {
    vec3 constrain_proj = constrain_dir * dot(constrain_dir, aPos.xyz);
    vec3 constrained_pos = aPos.xyz - constrain_proj;
    constrained_pos *= constrain_amt;
    constrained_pos += constrain_proj * (2.0 - constrain_amt);
    gl_Position = projection * transform * vec4(constrained_pos, aPos.w);
    // gl_Position = projection * transform * aPos;
    uv = vertexUV;
    time = i_time;
}
