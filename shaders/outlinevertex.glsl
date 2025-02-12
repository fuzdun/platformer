#version 450 core

layout (location = 0) in vec4 aPos;

// uniform mat4 transform;
uniform mat4 projection;
uniform vec3 player_pos_in;

void main() {
    float dist = max(0, player_pos_in.z - 50 - aPos.z);
    gl_Position = projection * (aPos + vec4(dist * dist * 0.01, dist * dist * 0.01, -dist * dist * 0.01, 0));
    // gl_Position = projection * aPos;// vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
