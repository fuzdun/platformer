#version 460 core

uniform vec3 edit_pos;

in vec3 color;
in vec3 pos;

out vec4 fragColor;

void main() {
    float dist = length(pos - edit_pos);
    vec3 new_color = color;
    new_color *= 1 - length(pos - edit_pos) / 300;
    if (new_color.r < 0.1) {
        discard;
    }
    fragColor = vec4(new_color, 1.0);
}

