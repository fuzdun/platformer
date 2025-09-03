#version 460 core

layout (location = 0) in vec4 a_pos;
layout (location = 1) in vec2 vertex_uv;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

layout (std430, binding = 2) buffer crack_time {
    float crack_time_data[];
};

layout (std430, binding = 4) buffer Transparencies_Data {
    float transparencies_data[];
};

uniform float shatter_delay;

out vec2 uv;
out float transparency;

#define BREAK_FADE_LEN 200.0

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * a_pos;
    uv = vertex_uv;
    float crack_time = crack_time_data[gl_BaseInstance + gl_InstanceID];
    float shatter_time = crack_time + shatter_delay;
    transparency = transparencies_data[gl_BaseInstance + gl_InstanceID];
    if (crack_time != 0 && i_time > shatter_time) {
        transparency = 1.0 - clamp((i_time - shatter_time) / BREAK_FADE_LEN, 0, 1);
    }
}

