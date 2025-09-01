#version 460 core

uniform vec3 color;

in float camera_dist;

out vec4 fragColor;

#define OPACITY_DIST 100.0

void main() {
    fragColor = vec4(color, clamp(camera_dist / OPACITY_DIST, 0.0, 1.0));
}

