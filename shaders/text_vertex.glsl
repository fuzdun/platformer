#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 uv_in;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

uniform mat4 transform;

out vec2 uv;

void main() {
    uv = uv_in;
    // gl_Position = projection * transform * aPos;
    gl_Position = aPos;
}

