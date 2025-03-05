#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

out VS_OUT {
    vec2 uv;
} vs_out;

void main() {
    // gl_Position = aPos;
    gl_Position = matrices_data[gl_InstanceID] *  aPos;
    vs_out.uv = vertexUV;
}

