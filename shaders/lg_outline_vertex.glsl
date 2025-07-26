#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std430, binding = 2) buffer crack_times {
    float crack_time_data[];
};

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

out vec2 uv;
out vec3 obj_pos;
out flat int cracked;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    float crack_time = crack_time_data[gl_BaseInstance + gl_InstanceID];
    cracked = (crack_time != 0 && i_time > crack_time) ? 1 : 0;
    obj_pos = vec3(transform[3][0], transform[3][1], transform[3][2]);
    gl_Position = projection * transform * aPos;
    uv = vertexUV;
}

