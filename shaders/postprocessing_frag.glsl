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
    float wave_f = sin(length(diff) * 10 - elapsed / 100 + 1.4);
    float fact = 1;
    float decay = max(elapsed / 100, 1);
    if (wave_f > 0) {
        fact = wave_f / 25.0 / max(elapsed / 100, 1);
        sample_uv += normalize(diff) * fact;
    }
    vec4 tex_color = texture(screenTexture, sample_uv);
    float average = 0.2126 * tex_color.r + 0.7152 * tex_color.g + 0.0722 * tex_color.b;
    // vec4 bw = vec4(average / 2, average / 2, average / 2, 1.0);
    vec4 bw = tex_color * 1.25;
    bw.r *= 2.0;
    // fragColor = mix(tex_color, bw,  min(1, max(0, wave_f / decay - 0.5)));
    fragColor = mix(tex_color, bw,  min(1, max(0, wave_f / decay - 0.25)));
    // fragColor = mix(tex_color, tex_color, wave_f / decay);
    // fragColor = bw;
}
