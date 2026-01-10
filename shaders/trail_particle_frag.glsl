#version 460 core

in vec2 uv;
in float intensity;

out vec4 fragColor;

void main() {
    float ax = (1.0 - smoothstep(0.2, 0.4, abs(uv.x - 0.5)));
    float ay =  smoothstep(0.0, 0.1, abs(uv.y)) - smoothstep(0.1, 1.0, abs(uv.y));
    float a = ax * ay;
    fragColor = vec4(a * a, a * a, 1.0, a * intensity);
}
