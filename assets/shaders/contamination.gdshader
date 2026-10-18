shader_type canvas_item;

// 프로젝트 벨카 - 규칙 위반 오염 (기본 디자인 시안 C: .contam-1~3, .contam-burst)
//   level 1 : 가장자리가 붉게 번진다
//   level 2 : + 가장자리 색이 어긋난다
//   level 3 : + 화면이 천천히 일렁인다 (motion = 0 이면 끈다)
//   burst   : 위반 순간 붉은 주사선 (1.4초 동안 1 → 0)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float level = 0.0;
uniform float burst = 0.0;
uniform float motion = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float wave = step(2.5, level) * motion;
	uv.x += sin(uv.y * 18.0 + TIME * 1.6) * 0.0022 * wave;
	uv.y += sin(uv.x * 12.0 + TIME * 1.1) * 0.0016 * wave;
	vec3 c = texture(screen_tex, uv).rgb;
	float edge = smoothstep(0.3, 0.75, length(UV - vec2(0.5)) * 1.25);
	if (level >= 1.5) {
		float shift = 0.0018 * edge;
		c.r = texture(screen_tex, uv + vec2(shift, 0.0)).r;
		c.b = texture(screen_tex, uv - vec2(shift, 0.0)).b;
	}
	c = mix(c, vec3(0.42, 0.04, 0.05), edge * 0.07 * clamp(level, 0.0, 3.0));
	float lines = step(0.5, fract(SCREEN_UV.y * 270.0 + TIME * 9.0 * motion));
	c = mix(c, vec3(0.75, 0.08, 0.06), burst * (0.05 + 0.12 * lines) * (0.5 + 0.5 * edge));
	COLOR = vec4(c, 1.0);
}
