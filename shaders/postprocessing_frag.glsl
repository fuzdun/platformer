#version 460 core

out vec4 fragColor;

in vec2 uv;

uniform sampler2D screenTexture;

void main() {
    fragColor = texture(screenTexture, uv);
    // float average = 0.2126 * fragColor.r + 0.7152 * fragColor.g + 0.0722 * fragColor.b;
    // fragColor = vec4(average, average, average, 1.0);
}
