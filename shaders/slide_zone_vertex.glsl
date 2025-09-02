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

layout (std430, binding = 4) buffer Transparencies_Data {
    float transparencies_data[];
};

out vec2 uv;
out float transparency;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * a_pos;
    uv = vertex_uv;
    transparency = transparencies_data[gl_BaseInstance + gl_InstanceID];
}

