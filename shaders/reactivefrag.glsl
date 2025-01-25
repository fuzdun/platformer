#version 450 core

out vec4 fragColor;

in vec3 player_pos;
in vec3 global_pos;
in float time;
in vec2 uv;

#define twopi 6.2831853
//
// float generator(vec2 uv,float x)
// {
//     return log(mod((min(length(uv.x),length(uv.y)))*x+length(uv)*(1.-x)-time*0.2,0.2)/0.2)/log(0.2);
// }
//
// void main()
// {
//
//     float d = length(global_pos.xz - player_pos.xz) + (global_pos.y + 0.5 - player_pos.y);
//     float a=1.5;
//     int n=15;
//     vec2 uv2=fract(uv)-0.5;
//     float x=(sin(1.*time+sin(floor(uv.x)*0.15+time*2.)+sin(floor(uv.y)*0.15+time*1.)+1.)/2.);
//     uv2=vec2(
//
//         cos(x*pi*a)*uv2.x - sin(x*pi*a)*uv2.y, 
//         sin(x*pi*a)*uv2.x + cos(x*pi*a)*uv2.y
//     );
//
//
//     // Time varying pixel color
//
//     vec3 col=vec3(0.05,0.1,0.1);
//     col = d < 3 ? col + vec3(1.0 - (0.75 * d), 0, 0) : col;
//     col*=generator(uv2,x);
//     fragColor = vec4(col,1.0);
// }

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float rand(float n){return fract(sin(n) * 43758.5453123);}

float noise(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
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
    vec3 diff = global_pos - player_pos;
    float a = atan(diff.x / diff.z) * 5;
    float uvd = length(global_pos.y + 0.5 - player_pos.y);
    float d = length(global_pos.xz - player_pos.xz) + noise(a + time * 10) * .3;
    float dfrac = d / uvd;
    float absd = abs(uvd - d);
    float border = smoothstep(-0.1, 0, absd) - smoothstep(0, 0.1, absd);
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

// void main() {
//     // fragColor = d < 8 ?vec4(1.0 - (0.2* d), .25, .5, 1) : vec4(0, 0.25, 0.5, 1);
//
// }

