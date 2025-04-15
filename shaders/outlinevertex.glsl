#version 450 core

layout (location = 0) in vec4 aPos;

uniform mat4 projection;

void main() {
    gl_Position = projection * aPos;
}
