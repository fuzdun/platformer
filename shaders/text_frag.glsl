#version 460 core

in vec2 uv;
out vec4 fragColor;

uniform sampler2D ourTexture;

void main() {
    float transparency = texture(ourTexture, uv).r;
    if (transparency == 0) {
        discard;
    }
    fragColor = vec4(1.0, 1.0, 1.0, transparency);
}

