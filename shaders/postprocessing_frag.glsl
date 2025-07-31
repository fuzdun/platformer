#version 460 core

out vec4 fragColor;

in vec2 uv;

uniform sampler2D screenTexture;
uniform float time;
uniform float crunch_time;
uniform vec2 ppos;

void main() {
    vec2 sample_uv = uv;
    vec2 diff = ppos - uv;
    float elapsed = time - crunch_time;
    float wave_f = sin(length(diff) * 3.5 * 3.14 - elapsed / 300 + .4);
    float fact = 1.0;
    float delay = clamp(elapsed / 400, .0001, 1.0);
    float decay = max(elapsed, 1) / 2000;
    float edge_dist = max(abs(uv.x - 0.5), abs(uv.y - 0.5));
    float edge_decay = 0.5 - edge_dist;
    float center_dist = length(diff);
    float center_decay = min(0.4, center_dist) / 0.4;
    fact = (wave_f / 20.0) / decay;
    float magnitude = fact * edge_decay * center_decay * delay;
    sample_uv += normalize(diff) * magnitude;
    vec4 tex_color = texture(screenTexture, sample_uv);
    vec4 bw = tex_color * ((delay * wave_f * 0.5 + 1.0) * 0.5 + 0.65);
    // bw.r *= 2.0;
    fragColor = mix(tex_color, bw,  clamp(wave_f / decay - 0.25, 0, 1));
}
