#version 460 core

in vec2 uv;
in float time;

uniform vec3 p_color;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

void main() {
    vec3 color = p_color;
    // if (color.g == 0) {
        // vec3 color = vec3(1.0, 0, 0);
    float t = time / 1000; 
    int BgIteration = int(t) + 12;

    for (int i = 0; i < BgIteration; i++) {
        float radiusNoise = noise(uv * 70.0 + float(i) + sin(t)) * 0.1;
        float radius = float(i) / 15.2 - t / 15.2 + radiusNoise - 0.25;

        if (abs(uv.y - 0.5) < radius) {
            color -= i > BgIteration - 2 ? vec3((fract(t)) * 0.1) : vec3(0.1);
        }
    }

    // }

    fragColor = vec4(color, 1.0);
    // fragColor = vec4(10, 0, 0, 1.0);
}
