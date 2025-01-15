#version 450 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 vertexUV;

out vec2 uv;

// uniform vec3 offset;
uniform mat4 scale;
uniform mat4 offset;
uniform mat4 view;
uniform mat4 rotate;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * offset * rotate * scale * vec4(aPos.x, aPos.y, aPos.z, 1.0);
    // gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    uv = vertexUV;
}
