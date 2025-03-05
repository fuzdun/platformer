#version 450 core

layout (location = 0) in vec4 aPos;
layout (location = 1) in vec2 vertexUV;
layout (location = 2) in vec3 normal_in;

layout (std430, binding = 0) buffer matrices {
    mat4 matrices_data[];
};

out vec2 uv;
out float time;

uniform float i_time;
uniform mat4 projection;

void main() {
    gl_Position = projection * matrices_data[gl_InstanceID] * aPos;
    uv = vertexUV;
    time = i_time;
}
