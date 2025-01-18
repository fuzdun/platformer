#version 450 core

layout (location = 0) in vec4 aPos;

// uniform mat4 transform;
uniform mat4 projection;

void main() {
    gl_Position = projection * aPos;// vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
