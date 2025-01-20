#version 450 core

in vec2 uv;
in float time;

out vec4 fragColor;

// vec3 palette( float t ) {
//     vec3 a = vec3(0.3, 0.3, 0.3);
//     vec3 b = vec3(0.3, 0.3, 0.3);
//     vec3 c = vec3(1.0, 1.0, 1.0);
//     vec3 d = vec3(0.263,0.416,0.557);

//     return a + b*cos( 6.28318*(c*t+d) );
// }

// void main() {
//     vec2 uv_2 = uv;
//     uv_2 += time / 20.0;
//     uv_2 = fract(uv_2 * 5.0);

//     vec3 col = vec3(0.0, 0.0, 0.5);

//     if (uv_2.x < abs(sin(uv_2.y + time))) {
//         col = palette(time);
//     }

//     if (uv_2.y < abs(sin(uv_2.x + time))) {
//         col = palette(time + 0.5);
//     }
//     fragColor = vec4(col,1.0);
// }
#define pi     3.14159265

float generator(vec2 uv,float x)
{
    return log(mod((min(length(uv.x),length(uv.y)))*x+length(uv)*(1.-x)-time*0.2,0.2)/0.2)/log(0.2);
}

void main()
{
    
    float a=1.5;
    int n=15;
    vec2 uv2=fract(uv)-0.5;
    float x=(sin(1.*time+sin(floor(uv.x)*0.15+time*2.)+sin(floor(uv.y)*0.15+time*1.)+1.)/2.);
    uv2=vec2(
    
        cos(x*pi*a)*uv2.x - sin(x*pi*a)*uv2.y, 
        sin(x*pi*a)*uv2.x + cos(x*pi*a)*uv2.y
    );
    
    
    // Time varying pixel color
    
    vec3 col=vec3(0.1,0.2,0.2)*generator(uv2,x);
    
    // Output to screen
    fragColor = vec4(col,1.0);
}