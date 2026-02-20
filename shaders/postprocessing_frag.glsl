#version 460 core

out vec4 fragColor;

in vec2 uv;

uniform sampler2D screenTexture;
uniform float crunch_time;
uniform vec2 ripple_pt;

layout (std140, binding = 0) uniform Combined
{
    vec3 player_pos;
	vec2 _padding0;
    mat4 projection;
    float i_time;
    float intensity;
    float dash_time;
    float dash_total;
    vec3 constrain_dir_in;
    float inner_tess;
    float outer_tess;
};

void main() {
    vec2 sample_uv = uv;
    vec2 diff = ripple_pt - uv;
    float elapsed = i_time - crunch_time;
    float wave_f = sin(length(diff) * 5.5 * 3.14 - elapsed / 200 + .7);
    float fact = 0.25 + (1.00 * intensity);
    // float fact = 0;//.25 + (0.25 * intensity);
    float delay = clamp(elapsed / 300, .0001, 1.0);
    float decay = max(elapsed, 1) / 1000;
    float edge_dist = max(abs(uv.x - 0.5), abs(uv.y - 0.5));
    float edge_decay = 0.5 - edge_dist;
    float center_dist = length(diff);
    float center_decay = min(0.6, center_dist) / 0.6;
    fact *= (wave_f / 7.5) / decay;
    float magnitude = fact * edge_decay * center_decay * delay;
    sample_uv += normalize(diff) * magnitude;
    vec4 tex_color = texture(screenTexture, sample_uv);
    vec4 bw = tex_color;// * ((delay * wave_f * 0.5 + 1.0) * 0.5 + 0.65);
    // vec4 bw = tex_color * ((delay * wave_f * 0.5 + 1.0) * 0.5 + 0.65);
    // bw.r *= 2.0;
    // fragColor = mix(tex_color, bw,  clamp(wave_f / decay - 0.25, 0, 1));
    fragColor = mix(tex_color, bw,  clamp(wave_f / decay - 0.25, 0, 1));
}
