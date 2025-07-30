#version 460 core

layout (location = 0) in vec4 aPos;
layout (location = 2) in vec3 color_in;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

out vec3 color;
out vec3 pos;

void main() {
    color = color_in;
    pos = aPos.xyz;
    gl_Position = projection * aPos;
}

