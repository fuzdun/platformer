#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float _;
};

out vec2 uv;
out vec3 obj_pos;

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    obj_pos = vec3(transform[3][0], transform[3][1], transform[3][2]);
    gl_Position = projection * transform * aPos;
    uv = vertexUV;
}

