#version 450 core

in vec2 uv;

out vec4 FragColor;

void main() {
    FragColor = vec4(uv[0] * 1.0f, uv[1] * 1.0f, 0.5f, 1.0f);
}