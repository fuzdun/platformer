#version 450 core

in vec2 uv;

out vec4 FragColor;

void main() {
    FragColor = vec4(uv[0] * 0.5 + 0.5, uv[1] * 0.5 + 0.5, 0.5f, 1.0f);
}