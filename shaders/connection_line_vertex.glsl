#version 460 core

layout (location = 0) in vec4 aPos;

layout (std140, binding = 0) uniform Common
{
    mat4 projection;
    float i_time;
};

void main() {
    gl_Position = projection * aPos;
}
