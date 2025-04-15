#version 450 core

out vec4 fragColor;

in vec3 player_pos;
in vec3 global_pos;
in float time;
in vec2 uv;

#define twopi 6.2831853

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float rand(float n){return fract(sin(n) * 43758.5453123);}

//float noise function 
float noise(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

//vec noise function
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
    vec3 diff = global_pos - player_pos;
    float a = atan(diff.x / diff.z) * 5;
    float uvd = length(global_pos.y + 0.5 - player_pos.y);
    float d = length(global_pos.xz - player_pos.xz) + noise(a + time * 10) * .3;
    float dfrac = d / uvd;
    float absd = abs(uvd - d);
    float border = smoothstep(-0.1, 0.0, absd) - smoothstep(0.0, 0.1, absd);
    // vec3 color = vec3(1.0);
    vec3 color = d < uvd ? vec3(.25, .15, max(1.0 - (d / uvd) * .5, 0.6)) : vec3(.25, .15, 0.6);
    color += vec3(.5, 0, 0) * border;
    float BgIteration = int(time) + 12;

    //Define edge noise
    for (int i = 0; i < BgIteration; i++) {
        float radiusNoise = noise(uv * 70.0 + float(i) + sin(time)) * 0.1;
        float radius = float(i) / 5.2 - time / 5.2 + radiusNoise;

        if (length(uv) < radius) {
            color.b -= i > BgIteration - 2 ? fract(time) * 0.05 : 0.05;
        }
    }

    fragColor = vec4(color, 1.0);
}

