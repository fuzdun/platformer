#version 460 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 8) readonly buffer input_0_buffer {

    uint input_0[];

};

void main() {

    uint index = gl_GlobalInvocationID.x;

    // data[index] = input_0[index] * input_1[index] * factor;

}
