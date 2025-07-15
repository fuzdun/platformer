#version 460 core

out vec4 fragColor;

in vec3 global_pos;
in noperspective vec2 affine_uv;
in vec2 perspective_uv;
in flat int in_view;
in vec3 normal_frag;
in vec3 player_pos;
in float i_time;
in float displacement;

in float plane_dist;
in vec3 t0_pos;
in vec3 t1_pos;
in vec3 t2_pos;
in vec2 t0_uv;
in vec2 t1_uv;
in vec2 t2_uv;

uniform vec3 camera_pos;
uniform vec3[3] player_trail;
uniform vec3 crunch_pt;
uniform float crunch_time;
uniform mat4 inverse_projection;
uniform mat4 inverse_view;

uniform sampler2D ditherTexture;

#define TWOPI 6.2831853
#define SHADES 3.0

vec3 colormap(float t) {
    const vec3 c0 = vec3(0.042660,0.186181,0.409512);
    const vec3 c1 = vec3(-0.703712,1.094974,2.049478);
    const vec3 c2 = vec3(7.995725,-0.686110,-4.998203);
    const vec3 c3 = vec3(-24.421963,2.680736,7.532937);
    const vec3 c4 = vec3(47.519089,-4.615112,-5.126531);
    const vec3 c5 = vec3(-46.038418,2.606781,0.685560);
    const vec3 c6 = vec3(16.586546,-0.279280,0.447047);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}


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
    float intv1 = sin((i_time / 4.0 + 12.0) / 10.0);
    float intv2 = cos((i_time / 4.0 + 12.0) / 10.0);

    mat2 mtx_off = mat2(intv1, 1.0, intv2, 1.0);
    mat2 mtx = mat2(1.6, 1.2, -1.2, 1.6);
    mtx = mtx_off * mtx;
    float f = 0.0;
    f += 0.25*noise( p + i_time / 4.0 * 1.5); p = mtx*p;
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

float reshapeUniformToTriangle(float v) {
    v = v * 2.0 - 1.0;
    v = sign(v) * (1.0 - sqrt(max(0.0, 1.0 - abs(v)))); // [-1, 1], max prevents NaNs
    return v + 0.5; // [-0.5, 1.5]
}

void main()
{
    // vec2 uv = in_view == 1 ? affine_uv : perspective_uv;
    // vec2 uv = perspective_uv;

    float screen_width = 1920.0;
    float screen_height = 1080.0;

    vec4 rounded_frag =  gl_FragCoord;
    vec2 screen_uv = gl_FragCoord.xy;
    screen_uv.x /= screen_width;
    screen_uv.y /= screen_width;
    screen_uv = floor(screen_uv * 512.0) / 512.0;
    // rounded_frag.xy = ceil(gl_FragCoord.xy / 6.0) * 6.0;
    rounded_frag.xy = screen_uv * screen_width;

    vec3 ndc = vec3(
        (rounded_frag.x / screen_width - 0.5) * 2.0,
        (rounded_frag.y / screen_height - 0.5) * 2.0,
        1.0
    );
    // vec3 t_normal = normalize(cross(t1_pos - t0_pos, t2_pos - t0_pos));
    vec4 ray_clip = vec4(ndc.xy, -1.0, 1.0);
    // ray_clip = ray_clip / ray_clip.w;
    vec4 ray_eye = inverse_projection * ray_clip;
    vec3 ray_wor = normalize((inverse_view * vec4(ray_eye.xy, -1.0, 0.0)).xyz);
    vec3 camera_off = -camera_pos;
    float plane_dist = dot(t0_pos, normal_frag);
    vec3 intersection = (plane_dist + dot(camera_off, normal_frag)) / dot(-normal_frag, ray_wor) * ray_wor + camera_off;
    intersection *= -1;

    vec3 v0 = t1_pos - t0_pos;
    vec3 v1 = t2_pos - t0_pos;
    vec3 v2 = intersection - t0_pos;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float denom =  d00 * d11 - d01 * d01;
    float bary_1 = (d11 * d20 - d01 * d21) / denom;
    float bary_2 = (d00 * d21 - d01 * d20) / denom;
    float bary_0 = 1.0 - bary_1 - bary_2;

    vec2 uv = t0_uv * bary_0 + t1_uv * bary_1 + t2_uv * bary_2;

    // uv = floor(uv * 64.0) / 64.0;
    float plane_off = dot(normal_frag, global_pos);
    float dist = dot(normal_frag, player_pos) - plane_off;
    vec3 proj_pt = player_pos - dist * normal_frag;

    vec3 diff = global_pos - player_pos;
    vec3 t_diff = intersection - player_pos;

    float a = atan(diff.x / diff.z) * 5;
    vec3 planar_diff = proj_pt - global_pos;
    float uvd = length(planar_diff);
    float d1 = dist + noise(a + i_time * 100) * .3;
    float dfrac = d1 / uvd;
    float absd = abs(uvd - d1);
    float noise_border = smoothstep(-0.1, 0.0, absd) - smoothstep(0.0, 0.1, absd);

    vec3 proximity_outline_col = vec3(1.0, .6, 1.0) * noise_border;
    vec3 proximity_shadow_col = d1 < uvd ? vec3(.5, .15, max(1.0 - (d1 / uvd) * .5, 0.6)) : vec3(.25, .45, 0.6);

    float shade = pattern(uv);
    vec3 pattern_col = vec3(colormap(shade).rgb);

    vec3 trail_col = vec3(0.0, 0, 0);
    vec2 res1 = distanceToSegment(player_pos, player_trail[0], global_pos);
    vec2 res2 = distanceToSegment(player_trail[0], player_trail[1], global_pos);
    vec2 res3 = distanceToSegment(player_trail[1], player_trail[2], global_pos);
    float d = min(res1[0], min(res2[0], res3[0]));
    float t = (d == res1[0] ? res1[1] : (d == res2[0] ? 1.0 + res2[1] : 2.0 + res3[1])) / 3.0;
    d += t * 0.69;
    float line_len = length(player_pos - player_trail[0]) + length(player_trail[1] - player_trail[0]) + length(player_trail[2] - player_trail[1]);
    float freq = 2.0 * line_len;
    float width =  sin(-i_time * 70.0 + t * TWOPI * freq) * 2.0 + 30.0;
    float border_d = 0.050 * width;
    vec3 intColor = mix(vec3(1.0, .5, 0.25), vec3(0.6, 0.0, 0.15), t);
    trail_col = res1[1] > 0.1 ?  mix(trail_col, intColor, 1.0-smoothstep(border_d - .004,border_d, d) ) : trail_col;

    vec3 impact_col = vec3(0.0);
    float crunch_dist = distance(global_pos, crunch_pt);    
    float k = crunch_dist - (i_time - crunch_time) * 30;
    float angle = atan(global_pos.z - crunch_pt.z, global_pos.x - crunch_pt.x);
    float w = crunch_dist + 25.7 * floor(angle / TWOPI * 10);
    angle -= (.2*jaggy(w/2) + .17*jaggy(w/1.7) + .13*jaggy(w/1.3)) / pow(crunch_dist, .5) * 20;
    float ripple_border = smoothstep(0, 6, k) - smoothstep(6, 12, k);
    angle = mod(angle, TWOPI / 10);
    if (0 <= angle && angle <= 2 / pow(crunch_dist, 1)) {
        impact_col = vec3(1.0, 0.0, 0.5) * ripple_border;
    }

    // vec3 col = mix(pattern_col + proximity_outline_col + trail_col + impact_col, proximity_shadow_col, 0.5);
    vec3 col = pattern_col + proximity_outline_col + trail_col + impact_col;

    // float mask = texture(ditherTexture, perspective_uv).r;
    // float mask = texture(ditherTexture, uv * 16.0).r;
    float mask = texture(ditherTexture, (screen_uv + player_pos.xz * vec2(1, -0.5) / 200.0) * 8.0).r;
    // float mask = texture(ditherTexture, perspective_uv * 4.0).r;
    mask = reshapeUniformToTriangle(mask);
    mask = min(1.0, max(floor(mask + length(t_diff) / 5.0) / 10.0, 0.15)); 
    // mask = 0.0; 
    // float visibility = length(diff) * 0.0025;
    // visibility = max(min(1.0, floor((visibility + mask / SHADES) * SHADES) / SHADES), .2);
    vec4 glassColor = mix(vec4(0.02, 0.04, 0.0, 0.40), vec4(0.05, 0.1, 0.0, 0.60), displacement);
    // float visibility = 1.0;
    // fragColor = mix(vec4(col, 1.0), glassColor, mask);
    fragColor = mix(vec4(col, 1.0), glassColor, mask);
    // fragColor = vec4();
    // fragColor = glassColor;
    // vec3 draw_normal = t_normal / 2.0 + vec3(0.5);
    // fragColor = vec4(ray_eye.x, bary_1, bary_2, 1.0);
    // fragColor = vec4(normal_frag.x, 0, 0, 1.0);
    // fragColor = vec4(intersection.x, intersection.y, intersection.z, 1.0);
    // if (sign(intersection.x) == 0) {
    //     fragColor = vec4(1.0, 0, 0, 1.0);
    // }
}

