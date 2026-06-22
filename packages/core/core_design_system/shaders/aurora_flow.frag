#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;

// 用于生成极光流光的噪声函数
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;

    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

float fbm(vec2 uv) {
    float f = 0.0;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    f  = 0.5000 * noise(uv); uv = m * uv;
    f += 0.2500 * noise(uv); uv = m * uv;
    f += 0.1250 * noise(uv); uv = m * uv;
    f += 0.0625 * noise(uv); uv = m * uv;
    return f;
}

out vec4 fragColor;

void main() {
    // 归一化坐标，并将原点移到中心
    vec2 uv = FlutterFragCoord().xy / u_resolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= u_resolution.x / u_resolution.y;

    // 旋转变换
    float a = u_time * 0.1; // 极慢的旋转速度
    mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
    vec2 rp = rot * p;

    // 计算流光场
    float q = fbm(rp * 1.5 + u_time * 0.05);
    vec2 r = vec2(fbm(rp + q + u_time * 0.02), fbm(rp + q - u_time * 0.05));
    float f = fbm(rp + r);

    // 混合颜色，使用原先指定的极光色域
    vec3 color1 = vec3(0.165, 0.031, 0.271); // 深邃紫 0xFF2A0845
    vec3 color2 = vec3(0.000, 0.255, 0.416); // 深海蓝 0xFF00416A
    vec3 color3 = vec3(0.392, 0.051, 0.078); // 猩红暗流 0xFF640D14
    
    // 背景为纯黑
    vec3 finalColor = vec3(0.0);
    
    // 基于噪声场平滑混合颜色
    finalColor = mix(finalColor, color1, smoothstep(0.0, 0.6, f));
    finalColor = mix(finalColor, color2, smoothstep(0.3, 0.8, f));
    finalColor = mix(finalColor, color3, smoothstep(0.5, 1.0, f));

    // 添加微弱的光晕中心
    float glow = exp(-length(p) * 1.5);
    finalColor += color1 * glow * 0.5;

    // 极度克制的透明度，保证作为背景不会抢夺视线
    fragColor = vec4(finalColor * 0.6, 1.0);
}
