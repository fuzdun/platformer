#version 450 core

out vec4 fragColor;

in vec3 player_pos;
in vec3[3] player_trail;
in vec3 global_pos;
in float time;
in vec2 uv;

#define TWOPI 6.2831853

vec2 distanceToSegment( vec2 a, vec2 b, vec2 p )
{
	vec2 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), .00, 1.00 );
	return vec2(length( pa - ba*h ), h);
}

float rand(float n){return fract(sin(n) * 43758.5453123);}

//float noise function 
float noise(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

void main()
{
    vec3 diff = global_pos - player_pos;
    float a = atan(diff.x / diff.z) * 5;
    float uvd = length(global_pos.y - player_pos.y);
    float d1 = length(global_pos.xz - player_pos.xz) + noise(a + time * 100) * .3;
    float dfrac = d1 / uvd;
    float absd = abs(uvd - d1);

    float noise_border = smoothstep(-0.1, 0.0, absd) - smoothstep(0.0, 0.1, absd);
    float color_fact = max(1.0 - (d1 / uvd) * .5, 0.6);
    vec3 reactive_color = d1 < uvd ? vec3(.7, .1, .7) * color_fact : vec3(.4, .15, .5);
    reactive_color += vec3(1, 0, 0) * noise_border;
	vec3 col = vec3(0.0);

    vec2 res1 = distanceToSegment(player_pos.xz, player_trail[0].xz, global_pos.xz);
    vec2 res2 = distanceToSegment(player_trail[0].xz, player_trail[1].xz, global_pos.xz);
    vec2 res3 = distanceToSegment(player_trail[1].xz, player_trail[2].xz, global_pos.xz);
    float d = min(res1[0], min(res2[0], res3[0]));
    float t = (d == res1[0] ? res1[1] : (d == res2[0] ? 1.0 + res2[1] : 2.0 + res3[1])) / 3.0;
    d += t * 0.69;

    float line_len = length(player_pos.xy - player_trail[0].xy) + length(player_trail[1] - player_trail[0]) + length(player_trail[2] - player_trail[1]);
    float freq = 2.0 * line_len;
    float width =  sin(-time * 70.0 + t * TWOPI * freq) * 5.0 + 40.0;
    float border_d = 0.01 * width;
    vec3 intColor = mix(vec3(1.0, 0.0, 0.0), vec3(0.5, 0.0, 0.5), t);
    col = res1[1] > 0.1 ?  mix( col, intColor, 1.0-smoothstep(border_d - .004,border_d, d) ) : col;

    col = mix(col, reactive_color, 0.5);
	fragColor = vec4( col, 1.0 );
}

