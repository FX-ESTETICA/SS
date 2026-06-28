#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float k1 = 0.366025404;
    const float k2 = 0.211324865;

    vec2 i = floor(p + (p.x + p.y) * k1);
    vec2 a = p - i + (i.x + i.y) * k2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + k2;
    vec2 c = a - 1.0 + 2.0 * k2;

    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

float fbm(vec2 uv) {
    float f = 0.0;
    mat2 m = mat2(1.7, 1.2, -1.2, 1.7);
    f  = 0.5000 * noise(uv); uv = m * uv;
    f += 0.2500 * noise(uv); uv = m * uv;
    f += 0.1250 * noise(uv); uv = m * uv;
    f += 0.0625 * noise(uv); uv = m * uv;
    return f;
}

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= u_resolution.x / u_resolution.y;

    float t = u_time * 0.12;
    float rotation = t * 0.7;
    mat2 rot = mat2(cos(rotation), -sin(rotation), sin(rotation), cos(rotation));
    vec2 rp = rot * p;

    float base = fbm(rp * 1.6 + vec2(0.0, t));
    float detail = fbm(rp * 2.4 - vec2(t * 0.6, -t * 0.4));
    float blend = smoothstep(0.05, 0.95, base * 0.7 + detail * 0.3 + 0.25);

    vec3 color1 = vec3(0.10, 0.01, 0.03);
    vec3 color2 = vec3(0.48, 0.05, 0.18);
    vec3 color3 = vec3(1.00, 0.36, 0.34);

    vec3 finalColor = vec3(0.0);
    finalColor = mix(finalColor, color1, smoothstep(0.00, 0.45, blend));
    finalColor = mix(finalColor, color2, smoothstep(0.20, 0.75, blend));
    finalColor = mix(finalColor, color3, smoothstep(0.58, 1.00, blend));

    float glow = exp(-length(p) * 1.8);
    finalColor += color2 * glow * 0.35;
    finalColor += color3 * glow * 0.10;

    fragColor = vec4(finalColor * 0.62, 1.0);
}
