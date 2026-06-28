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
    mat2 m = mat2(1.5, 1.1, -1.1, 1.5);
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

    float t = u_time * 0.10;
    vec2 drift = vec2(t * 0.6, -t * 0.25);
    float fieldA = fbm(p * 1.4 + drift);
    float fieldB = fbm(p * 2.0 - drift * 1.6);
    float glowBand = sin((p.y + fieldA * 0.4) * 6.0 - t * 3.2) * 0.5 + 0.5;
    float f = smoothstep(0.02, 0.98, fieldA * 0.55 + fieldB * 0.25 + glowBand * 0.20 + 0.20);

    vec3 color1 = vec3(0.00, 0.07, 0.11);
    vec3 color2 = vec3(0.00, 0.37, 0.48);
    vec3 color3 = vec3(0.39, 0.90, 1.00);

    vec3 finalColor = vec3(0.0);
    finalColor = mix(finalColor, color1, smoothstep(0.00, 0.48, f));
    finalColor = mix(finalColor, color2, smoothstep(0.22, 0.76, f));
    finalColor = mix(finalColor, color3, smoothstep(0.62, 1.00, f));

    float center = exp(-length(p * vec2(1.0, 1.3)) * 2.2);
    finalColor += color3 * center * 0.18;

    fragColor = vec4(finalColor * 0.60, 1.0);
}
