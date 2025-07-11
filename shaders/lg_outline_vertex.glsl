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

void main() {
    mat4 transform = matrices_data[gl_BaseInstance + gl_InstanceID];
    gl_Position = projection * transform * aPos;
    uv = vertexUV;
}

