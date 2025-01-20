#version 450 core

in vec2 uv;
in float time;

out vec4 fragColor;
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

//Noise function
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

//White Hole draw
void main() {
    vec3 color = vec3(1.0);
    int BgIteration = int(time) + 12;

    //Define edge noise
    for (int i = 0; i < BgIteration; i++) {
        float radiusNoise = noise(uv * 70.0 + float(i) + sin(time)) * 0.1;
        float radius = float(i) / 5.2 - time / 5.2 + radiusNoise;

        if (length(uv) < radius) {
            color -= i > BgIteration - 2 ? vec3((fract(time)) * 0.1) : vec3(0.1);
        }
    }

    fragColor = vec4(color, 1.0);
}
