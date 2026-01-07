#version 460 core

in vec2 uv;
in float intensity;

out vec4 fragColor;

void main() {
    float a = intensity * (1.0 - (smoothstep(0.1, 0.5, abs(uv.x - 0.5)) + uv.y));
    fragColor = vec4(a * a, a * a, 1.0, a);
    // fragColor = vec4(1);
}
