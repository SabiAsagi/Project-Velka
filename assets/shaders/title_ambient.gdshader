shader_type canvas_item;

// 프로젝트 벨카 - 타이틀 조명 (피그마 시안 오염 테마 .ambient-light) — 아래층부터 차례로 덮는다
//   1. 아래 → 위: rgba(4,4,6,.85) → 투명 (45%)
//   2. 왼쪽 → 오른쪽: rgba(6,6,8) .99 / .92@26% / .30@56% / .12@100%
//   3. 가운데 비네트: 투명 40% → 검정 .82 (가장 먼 모서리)
//   4. 붉은 기운: 타원 60% x 55% @ (72%, 42%), rgba(90,18,26,.22) → 투명 70%
// 9초마다 잠깐 깜빡이는 것(ambient-flicker)은 GDScript 가 modulate 로 한다.

vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 c = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 0.0001);
	return vec4(c, a);
}

float ramp(float x, float x0, float a0, float x1, float a1) {
	return mix(a0, a1, clamp((x - x0) / (x1 - x0), 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV;
	float up = 1.0 - uv.y;
	vec4 col = vec4(4.0 / 255.0, 4.0 / 255.0, 6.0 / 255.0, 0.85 * clamp(1.0 - up / 0.45, 0.0, 1.0));
	float h = uv.x < 0.26 ? ramp(uv.x, 0.0, 0.99, 0.26, 0.92)
			: (uv.x < 0.56 ? ramp(uv.x, 0.26, 0.92, 0.56, 0.30) : ramp(uv.x, 0.56, 0.30, 1.0, 0.12));
	col = over(col, vec4(6.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, h));
	float d = length((uv - 0.5) * 2.0) / sqrt(2.0);
	col = over(col, vec4(0.0, 0.0, 0.0, 0.82 * clamp((d - 0.4) / 0.6, 0.0, 1.0)));
	float r = length((uv - vec2(0.72, 0.42)) / vec2(0.6, 0.55));
	col = over(col, vec4(90.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.22 * clamp(1.0 - r / 0.7, 0.0, 1.0)));
	COLOR = col;
}
