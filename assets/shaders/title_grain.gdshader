shader_type canvas_item;

// 프로젝트 벨카 - 타이틀 화면 결 (피그마 시안 오염 테마: .screen-grain opacity .09 · .scanline opacity .18)
//   결   : 잿빛 잡음 (원본 SVG feTurbulence 는 알파도 섞여 있어 크롬 렌더와 밝기를 맞춘 .6 × .9 × .09)
//   주사선: 4px 마다 한 줄, 흰색 2.5% × .18
uniform float grain = 0.09;
uniform float scan = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	float a1 = grain * 0.9 * 0.6;
	vec3 c1 = vec3(hash(px));
	float a2 = scan * 0.025 * step(3.0, mod(px.y, 4.0));
	float a = a1 + a2 * (1.0 - a1);
	COLOR = vec4((c1 * a1 * (1.0 - a2) + vec3(1.0) * a2) / a, a);
}
