#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

out VS_OUT {
    vec2 uv;
} vs_out;

// uniform mat4 transform;

void main() {
    vec4 new_pos = aPos;
    gl_Position = new_pos;
    vs_out.uv = vertexUV;
}

