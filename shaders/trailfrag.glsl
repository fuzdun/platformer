#version 460 core

out vec4 fragColor;

in vec3 global_pos;
in noperspective vec2 affine_uv;
in vec2 perspective_uv;
in flat int in_view;
in vec3 normal_frag;
in vec3 player_pos;

uniform float sonar_time;
uniform float time;
uniform vec3[3] player_trail;
uniform vec3 crunch_pt;
uniform float crunch_time;

#define TWOPI 6.2831853

float colormap_red(float x) {
    if (x < 0.0) {
        return 167.0;
    } else if (x < (2.54491177159840E+02 + 2.49117061281287E+02) / (1.94999353031535E+00 + 1.94987400471999E+00)) {
        return -1.94987400471999E+00 * x + 2.54491177159840E+02;
    } else if (x <= 255.0) {
        return 1.94999353031535E+00 * x - 2.49117061281287E+02;
    } else {
        return 251.0;
    }
}

float colormap_green(float x) {
    if (x < 0.0) {
        return 112.0;
    } else if (x < (2.13852573128775E+02 + 1.42633630462899E+02) / (1.31530121382008E+00 + 1.39181683887691E+00)) {
        return -1.39181683887691E+00 * x + 2.13852573128775E+02;
    } else if (x <= 255.0) {
        return 1.31530121382008E+00 * x - 1.42633630462899E+02;
    } else {
        return 195.0;
    }
}

float colormap_blue(float x) {
    if (x < 0.0) {
        return 255.0;
    } else if (x <= 255.0) {
        return -9.84241021836929E-01 * x + 2.52502692064968E+02;
    } else {
        return 0.0;
    }
}

vec4 colormap(float x) {
    float t = x * 255.0;
    float r = colormap_red(t) / 255.0;
    float g = colormap_green(t) / 255.0;
    float b = colormap_blue(t) / 255.0;
    return vec4(r, g, b, 1.0);
}

//White Hole draw
vec2 distanceToSegment( vec3 a, vec3 b, vec3 p )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), .00, 1.00 );
	return vec2(length( pa - ba*h ), h);
}

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

float fbm (vec2 p )
{
    float intv1 = sin((time + 12.0) / 10.0);
    float intv2 = cos((time + 12.0) / 10.0);

    mat2 mtx_off = mat2(intv1, 1.0, intv2, 1.0);
    mat2 mtx = mat2(1.6, 1.2, -1.2, 1.6);
    mtx = mtx_off * mtx;
    float f = 0.0;
    f += 0.25*noise( p + time * 1.5); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p ); p = mtx*p;
    f += 0.25*noise( p );
    return f;
}

float pattern( in vec2 p )
{
	return fbm(p + fbm(p + fbm(p)));
}

float jaggy(float x)
{
    return abs(mod(x, 1) - .5) - .5;
}

void main()
{
    vec2 uv = in_view == 1 ? affine_uv : perspective_uv;
    float plane_off = dot(normal_frag, global_pos);
    float dist = dot(normal_frag, player_pos) - plane_off;
    vec3 proj_pt = player_pos - dist * normal_frag;

    vec3 diff = global_pos - player_pos;

    float a = atan(diff.x / diff.z) * 5;
    float uvd = length(global_pos - proj_pt);
    float d1 = dist + noise(a + time * 100) * .3;
    float dfrac = d1 / uvd;
    float absd = abs(uvd - d1);
    float noise_border = smoothstep(-0.1, 0.0, absd) - smoothstep(0.0, 0.1, absd);

    vec3 proximity_outline_col = vec3(1.0, .6, 1.0) * noise_border;
    vec3 proximity_shadow_col = d1 < uvd ? vec3(.5, .15, max(1.0 - (d1 / uvd) * .5, 0.6)) : vec3(.25, .45, 0.6);

    float shade = pattern(uv);
    vec3 pattern_col = vec3(colormap(shade).rgb) * 0.5;

    vec3 trail_col = vec3(0.0, 0, 0);
    vec2 res1 = distanceToSegment(player_pos, player_trail[0], global_pos);
    vec2 res2 = distanceToSegment(player_trail[0], player_trail[1], global_pos);
    vec2 res3 = distanceToSegment(player_trail[1], player_trail[2], global_pos);
    float d = min(res1[0], min(res2[0], res3[0]));
    float t = (d == res1[0] ? res1[1] : (d == res2[0] ? 1.0 + res2[1] : 2.0 + res3[1])) / 3.0;
    d += t * 0.69;
    float line_len = length(player_pos - player_trail[0]) + length(player_trail[1] - player_trail[0]) + length(player_trail[2] - player_trail[1]);
    float freq = 2.0 * line_len;
    float width =  sin(-time * 70.0 + t * TWOPI * freq) * 2.0 + 40.0;
    float border_d = 0.050 * width;
    vec3 intColor = mix(vec3(1.0, .5, 0.25), vec3(0.5, 0.0, 0.5), t);
    trail_col = res1[1] > 0.1 ?  mix(trail_col, intColor, 1.0-smoothstep(border_d - .004,border_d, d) ) : trail_col;

    vec3 impact_col = vec3(0.0);
    float crunch_dist = distance(global_pos, crunch_pt);    
    float k = crunch_dist - (time - crunch_time) * 30;
    float angle = atan(global_pos.z - crunch_pt.z, global_pos.x - crunch_pt.x);
    float w = crunch_dist + 25.7 * floor(angle / TWOPI * 10);
    angle -= (.2*jaggy(w/2) + .17*jaggy(w/1.7) + .13*jaggy(w/1.3)) / pow(crunch_dist, .5) * 20;
    float ripple_border = smoothstep(0, 6, k) - smoothstep(6, 12, k);
    angle = mod(angle, TWOPI / 10);
    if (0 <= angle && angle <= 2 / pow(crunch_dist, 1)) {
        impact_col = vec3(1.0, 0.0, 0.5) * ripple_border;
    }

    float v_border = .02;
    float h_border = .02;

    float x_border_fact = smoothstep(1.0 - h_border, 1.0, uv.x) +
        1.0 - smoothstep(0.0, h_border, uv.x);
    float y_border_fact = smoothstep(1.0 - v_border, 1.0, uv.y) +
        1.0 - smoothstep(0.0, v_border, uv.y);
    float border_fact = max(x_border_fact, y_border_fact);
    vec3 border_col = border_fact * vec3(1.0, 0.8, 1.0);
    vec3 col = mix(pattern_col + border_col + proximity_outline_col + trail_col + impact_col, proximity_shadow_col, 0.5);

    fragColor = vec4(col, 1.0);
    // fragColor = vec4(0.0, 0.0, 1.0, 1.0);
}

