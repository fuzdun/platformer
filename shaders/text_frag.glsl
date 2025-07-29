#version 460 core

in vec2 uv;
out vec4 fragColor;

uniform sampler2D ourTexture;

void main() {
    fragColor = vec4(1.0, 1.0, 1.0, texture(ourTexture, uv).r);
}

