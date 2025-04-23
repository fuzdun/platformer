#version 460 core

in vec2 uv;
out vec4 fragColor;

void main() {
    float radius = length(uv - vec2(0.5, 0.5));
    float t_fact = 1.0 - smoothstep(0.4, 0.45, radius);
    fragColor = vec4(1.0, 0.6, 0.6, t_fact);
}

