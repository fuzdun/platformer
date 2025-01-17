#version 450 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 vertexUV;

out vec2 uv;
out float time;

uniform float i_time;
uniform mat4 transform;
uniform mat4 projection;

void main() {
    gl_Position = projection * transform * vec4(aPos.x, aPos.y, aPos.z, 1.0);
    uv = vertexUV;
    time = i_time;
}
