shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 프로젝트 벨카 - 학교 맵 공용 표면 셰이더
// 벽·바닥·가구·부지가 함께 쓴다. 기능:
//   1) 컷어웨이: 카메라와 조작 캐릭터 사이(카메라 쪽 부채꼴)의 면을 캐릭터 주변 원 안에서 디더링으로 걷어낸다.
//      캐릭터 발 높이 + cutaway_min_height 아래는 남겨 벽 위치가 읽히게 하고, 낮은 가구는 지우지 않는다.
//   2) 사진 텍스처(CC0): 건물·지면은 월드 좌표로, 가구는 박스 자기 좌표로 투영한다 (나뭇결이 면의 긴 변을 따른다).
//      텍스처를 평균색(surf_avg)으로 나눠 무늬만 얹으므로 팔레트 색이 그대로 표면의 평균색이 된다.
//   3) 아래 띠 (굽도리·외벽 하단 마감, 띠 전용 텍스처), 타일 줄눈과 타일별 색 차이.
//   4) 사용감: 얼룩·물 얼룩·벽 밑 때·손때·빗물 자국·누수 자국·모서리 마모·바닥 가장자리 때·녹·젖은 자국·물체별 색 차이.
//      노이즈 텍스처(R 큰 얼룩, G 중간 얼룩, B 잔결, A 금·긁힘)로 위치마다 다르게 깨뜨린다.

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const float LEVEL_H = 3.8;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy = 0.0;
// 아래 띠: 0 이하면 없음. band_absolute 0 = 층 바닥 기준(3.8m 주기), 1 = band_base 기준 절대 높이
uniform vec4 band_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float band_height = 0.0;
uniform float band_absolute = 0.0;
uniform float band_base = 0.0;
// 타일 줄눈 (수평면 tile_size, 수직면 wall_tile_size, m), 타일마다 밝기 차이
uniform float tile_size = 0.0;
uniform vec4 tile_line_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float wall_tile_size = 0.0;
uniform float tile_var = 0.0;
// 컷어웨이: 1 = 적용, 반경 배율, 발 높이에서 이 높이까지는 남김, 부채꼴 옆 가장자리 흐림 폭(m)
uniform float cutaway_affected = 1.0;
uniform float cutaway_scale = 1.0;
uniform float cutaway_min_height = 0.35;
uniform float cutaway_wedge_fade = 0.0;

// 사진 텍스처. surf_scale = 텍스처 한 장이 덮는 길이(m), 0이면 쓰지 않는다
uniform sampler2D surf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surf_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 surf_avg = vec3(0.5);
uniform float surf_scale = 0.0;
// 무늬 세기, 색 차이까지 옮기는 정도(0 = 밝기만), 노멀 세기
uniform float surf_mix = 1.0;
uniform float surf_chroma = 0.5;
uniform float surf_nrm_strength = 0.0;
// 1 = 박스 자기 좌표 (가구·소품), 1 = 넓은 지면의 반복 무늬 흐리기
uniform float object_space = 0.0;
uniform float anti_tile = 0.0;
// 띠 전용 텍스처
uniform sampler2D band_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 band_avg = vec3(0.5);
uniform float band_scale = 0.0;
// 겹 텍스처 (128px 공포 텍스처: 잔 얼룩·긁힘을 밝기로만 얹는다)
uniform sampler2D over_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 over_avg = vec3(0.5);
uniform float over_scale = 0.0;
uniform float over_mix = 0.0;
// 공용 노이즈, 누수 자국 (Leaking 불투명도)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D leak_tex : hint_default_black, filter_linear_mipmap, repeat_enable;

// 사용감
uniform float grime = 0.05;
uniform float stain = 0.0;
uniform vec4 stain_color : source_color = vec4(0.55, 0.47, 0.34, 1.0);
uniform float base_dirt = 0.0;
uniform float hand_dirt = 0.0;
uniform float streaks = 0.0;
uniform float leak = 0.0;
// 벽 밑에서 스며 오른 습기의 평균 높이(m). 0 = 없음
uniform float damp = 0.0;
// 모서리: + 밝게 벗겨짐(wear_color), - 어두운 손때. edge_dirt = 바닥 판 가장자리(벽 밑) 때
uniform float edge_wear = 0.0;
uniform vec4 wear_color : source_color = vec4(0.62, 0.6, 0.56, 1.0);
uniform float edge_dirt = 0.0;
uniform float rust = 0.0;
uniform float wet = 0.0;
uniform float inst_var = 0.0;
// 닳은 도색 (도로·주차선·코트선·바닥 표시): 노이즈가 높은 곳의 칠을 벗겨 아래 바닥이 드러나게 한다
uniform float paint_wear = 0.0;
// 1 = 원통·원뿔 (박스 모서리 계산을 하지 않고 월드 좌표로 투영)
uniform float shape_round = 0.0;

global uniform vec3 cutaway_center;
global uniform float cutaway_radius;
// 이계 부식도 (WorldPhaseController가 설정, 0 = 현실, 1 = 이계): 얼룩·누수·습기·녹·때가 짙어진다
global uniform float world_decay;
// 사용감 전체 세기 (project.godot 전역 셰이더 파라미터, 1.0 = 재질별 기본값 그대로).
// 재질마다 따로 고치지 않고 맵 전체의 분위기를 한 번에 맞출 때 쓴다.
global uniform float wear_dirt_scale;   // 더러움: 때·얼룩·벽 밑 때·손때·빗물 자국·바닥 가장자리 먼지·젖은 자국
global uniform float wear_age_scale;    // 낡은 정도: 모서리 벗겨짐·닳은 도색·녹
global uniform float wear_horror_scale; // 공포: 누수·습기, 이계 부식도(world_decay)가 더하는 양

varying vec3 v_wp;
varying vec3 v_lp;
varying vec3 v_ln;
varying flat vec3 v_half;
varying flat vec3 v_ax;
varying flat vec3 v_ay;
varying flat vec3 v_az;
varying flat float v_seed;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float bayer4(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	int i = x + y * 4;
	float m[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };
	return (m[i] + 0.5) / 16.0;
}

vec3 tex_detail(vec3 s, vec3 avg, float chroma) {
	float l = dot(s, LUMA) / max(dot(avg, LUMA), 0.002);
	return clamp(mix(vec3(l), s / max(avg, vec3(0.002)), chroma), vec3(0.0), vec3(2.4));
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 멀티메시는 단위 박스를 인스턴스 변환으로 늘리고, 일반 메시는 크기가 든 박스를 그대로 쓴다. 둘 다 미터 단위 자기 좌표가 된다
	vec3 scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_ax = MODEL_MATRIX[0].xyz / max(scl.x, 1e-5);
	v_ay = MODEL_MATRIX[1].xyz / max(scl.y, 1e-5);
	v_az = MODEL_MATRIX[2].xyz / max(scl.z, 1e-5);
	v_lp = VERTEX * scl;
	v_half = abs(VERTEX) * scl;
	v_ln = NORMAL;
	v_seed = hash13(MODEL_MATRIX[3].xyz * 1.7 + 0.31);
}

void fragment() {
	vec3 wp = v_wp;

	// 그림자 패스에서는 걷어내지 않는다: 걷어낸 벽·나무도 그림자는 그대로 드리워, 그림자에 조각난 구멍이 생기지 않는다
	if (cutaway_affected > 0.5 && cutaway_radius > 0.0 && !IN_SHADOW_PASS) {
		vec3 center = cutaway_center + vec3(0.0, 1.0, 0.0);
		vec3 cv = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
		float frag_depth = -VERTEX.z;
		float center_depth = -cv.z;
		// 카메라와 캐릭터 사이에 있는 면만 걷어낸다. 깊이만 비교하면 캐릭터 뒤·옆 벽도 (카메라가 비스듬히 내려다보므로)
		// 윗부분이나 카메라 쪽으로 뻗은 부분이 "더 가깝다"고 판정되어 뚫리고 건물 밖이 보인다.
		// 그래서 캐릭터에서 카메라 쪽으로 열린 90도 부채꼴(수평) 안에 있는 면만 대상으로 삼는다.
		vec2 rel = wp.xz - cutaway_center.xz;
		vec2 h = normalize(CAMERA_POSITION_WORLD.xz - cutaway_center.xz);
		vec2 wedge_a = vec2(h.x - h.y, h.x + h.y) * 0.70710678;
		vec2 wedge_b = vec2(h.x + h.y, h.y - h.x) * 0.70710678;
		float wedge_d = min(dot(rel, wedge_a), dot(rel, wedge_b));
		float wedge_in = cutaway_wedge_fade > 0.0 ? smoothstep(-0.25 - cutaway_wedge_fade, -0.25, wedge_d) : step(-0.25, wedge_d);
		if (center_depth > 0.1 && wedge_in > 0.0 && frag_depth < center_depth && wp.y > cutaway_center.y + cutaway_min_height) {
			vec2 fp = VERTEX.xy / frag_depth;
			vec2 cp = cv.xy / center_depth;
			float d = length(fp - cp) * center_depth;
			float r = cutaway_radius * cutaway_scale;
			float inside = (1.0 - smoothstep(r * 0.72, r, d)) * wedge_in;
			if (inside > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}

	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// 면 좌표계: U = 텍스처 오른쪽, V = 텍스처 위, N = 바깥. 투영 좌표 uv = (p·U, -p·V), 단위 m
	vec3 U;
	vec3 V;
	vec3 N = wn;
	vec2 uv;
	if (object_space > 0.5 && shape_round < 0.5) {
		vec3 an = abs(v_ln);
		vec3 ul;
		vec3 vl;
		if (an.y >= an.x && an.y >= an.z) {
			ul = vec3(1.0, 0.0, 0.0);
			vl = vec3(0.0, 0.0, -sign(v_ln.y));
		} else if (an.x >= an.z) {
			ul = vec3(0.0, 0.0, -sign(v_ln.x));
			vl = vec3(0.0, 1.0, 0.0);
		} else {
			ul = vec3(sign(v_ln.z), 0.0, 0.0);
			vl = vec3(0.0, 1.0, 0.0);
		}
		// 결 방향: 텍스처 가로를 면의 긴 변에 맞춘다 (책상 상판·기둥·선반 판)
		if (dot(abs(vl), v_half) > dot(abs(ul), v_half) * 1.15) {
			vec3 t = ul;
			ul = vl;
			vl = -t;
		}
		// 물체마다 텍스처의 다른 자리를 쓰게 밀어 둔다
		vec3 p = v_lp + vec3(17.3, 5.1, 11.7) * v_seed;
		uv = vec2(dot(p, ul), -dot(p, vl));
		U = normalize(ul.x * v_ax + ul.y * v_ay + ul.z * v_az);
		V = normalize(vl.x * v_ax + vl.y * v_ay + vl.z * v_az);
	} else {
		vec3 an = abs(wn);
		if (an.y >= an.x && an.y >= an.z) {
			U = vec3(1.0, 0.0, 0.0);
			V = vec3(0.0, 0.0, -sign(wn.y));
		} else if (an.x >= an.z) {
			U = vec3(0.0, 0.0, -sign(wn.x));
			V = vec3(0.0, 1.0, 0.0);
		} else {
			U = vec3(sign(wn.z), 0.0, 0.0);
			V = vec3(0.0, 1.0, 0.0);
		}
		uv = vec2(dot(wp, U), -dot(wp, V));
	}

	vec3 col = albedo.rgb;
	float lum_d = 1.0;
	vec2 st = uv / max(surf_scale, 0.001);
	if (surf_scale > 0.0) {
		vec3 s = texture(surf_tex, st).rgb;
		if (anti_tile > 0.5) {
			// 넓은 지면: 돌리고 옮긴 두 번째 샘플을 큰 얼룩 노이즈로 섞어 반복 무늬를 흐린다
			vec2 st2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * st * 0.87 + vec2(0.37, 0.71);
			float m = smoothstep(0.38, 0.62, texture(noise_tex, uv / (surf_scale * 4.1)).r);
			s = mix(s, texture(surf_tex, st2).rgb, m);
		}
		vec3 d = tex_detail(s, surf_avg, surf_chroma);
		col *= mix(vec3(1.0), d, surf_mix);
		lum_d = dot(s, LUMA) / max(dot(surf_avg, LUMA), 0.002);
	}

	// 층 바닥(3.8m 주기)에서의 높이, 띠·벽 밑 때의 기준 높이
	float h_lvl = wp.y - floor((wp.y + 0.25) / LEVEL_H) * LEVEL_H;
	float h_ref = band_absolute > 0.5 ? wp.y - band_base : h_lvl;
	if (band_height > 0.0) {
		float in_band = 1.0 - step(band_height, h_ref);
		vec3 bc = band_color.rgb;
		if (band_scale > 0.0) {
			bc *= tex_detail(texture(band_tex, uv / band_scale).rgb, band_avg, 0.5);
		} else {
			bc *= mix(1.0, clamp(lum_d, 0.0, 2.0), surf_mix * 0.7);
		}
		col = mix(col, bc, in_band);
		// 띠 윗선 (몰딩)
		float line = (1.0 - smoothstep(0.0, 0.025, abs(h_ref - band_height))) * 0.35;
		col *= 1.0 - line;
	}
	if (tile_size > 0.0 && wn.y > 0.7) {
		vec2 tc = wp.xz / tile_size;
		vec2 t = fract(tc);
		float e = min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y)) * tile_size;
		if (tile_var > 0.0) {
			col *= 1.0 + (hash13(vec3(floor(tc), 3.7)) - 0.5) * 2.0 * tile_var;
		}
		col = mix(col, tile_line_color.rgb, (1.0 - smoothstep(0.004, 0.012, e)) * 0.8);
	}
	if (wall_tile_size > 0.0 && abs(wn.y) < 0.3) {
		vec2 tc = (abs(wn.x) > 0.7 ? wp.zy : wp.xy) / wall_tile_size;
		vec2 t = fract(tc);
		float e = min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y)) * wall_tile_size;
		if (tile_var > 0.0) {
			col *= 1.0 + (hash13(vec3(floor(tc), 9.1)) - 0.5) * 2.0 * tile_var;
		}
		col = mix(col, col * 0.78, 1.0 - smoothstep(0.002, 0.008, e));
	}
	if (over_mix > 0.0 && over_scale > 0.0) {
		vec3 o = texture(over_tex, uv / over_scale + vec2(0.13, 0.41)).rgb;
		float ol = dot(o, LUMA) / max(dot(over_avg, LUMA), 0.002);
		col *= mix(1.0, clamp(ol, 0.0, 2.0), over_mix);
	}

	// 닳은 도색: discard 판정에 쓰는 노이즈는 이 재질에서만 샘플한다 (깊이·그림자 패스 비용)
	float k_dirt = max(wear_dirt_scale, 0.0);
	float k_age = max(wear_age_scale, 0.0);
	float k_horror = max(wear_horror_scale, 0.0);
	float paint_wear_k = paint_wear * k_age;
	if (paint_wear_k > 0.0) {
		float pw = (texture(noise_tex, uv / 1.37 + vec2(0.53, 0.11)).g - 0.5) * 0.6
			+ (texture(noise_tex, uv / 5.3 + vec2(0.21, 0.67)).r - 0.5) * 0.4
			+ (texture(noise_tex, uv / 0.29 + vec2(0.3, 0.8)).b - 0.5) * 0.5;
		if (pw > 0.25 - paint_wear_k * 0.3) {
			discard;
		}
		col *= 0.88 + 0.12 * smoothstep(0.1, -0.15, pw);
	}

	// 사용감 레이어 (이계에서는 world_decay만큼 짙어진다)
	vec4 nb = texture(noise_tex, uv / 5.3 + vec2(0.21, 0.67));
	vec4 nf = texture(noise_tex, uv / 1.37 + vec2(0.53, 0.11));
	float decay = clamp(world_decay, 0.0, 1.0);
	float decay_k = decay * k_horror;
	float stain_k = stain * k_dirt + decay_k * 0.5;
	// 누수·습기는 건물(월드 좌표 재질)에만 번진다
	float arch = 1.0 - step(0.5, object_space);
	float leak_k = (leak + decay * 0.6 * arch) * k_horror;
	float damp_k = (damp + decay * 0.7 * arch) * k_horror;
	float rust_k = rust > 0.0 ? rust * k_age + decay_k * 0.35 : 0.0;
	float base_dirt_k = base_dirt * k_dirt;
	float hand_dirt_k = hand_dirt * k_dirt;
	float streaks_k = streaks * k_dirt;
	float edge_dirt_k = edge_dirt * k_dirt;
	float edge_wear_k = edge_wear * k_age;
	float wet_k = wet * k_dirt;
	vec3 stain_c = mix(stain_color.rgb, vec3(0.42, 0.2, 0.17), decay * 0.6);
	if (grime > 0.0) {
		float gk = grime * k_dirt + decay_k * 0.12;
		float g = nb.r * 0.55 + nf.g * 0.45;
		col *= 1.0 - gk + g * gk * 1.4;
	}
	if (stain_k > 0.0) {
		// 물 얼룩: 안쪽은 누렇게 어둡고, 가장자리에 마른 물때 선이 남는다
		float s = nb.g;
		float blob = smoothstep(0.6, 0.7, s);
		float ring = smoothstep(0.57, 0.61, s) * (1.0 - smoothstep(0.61, 0.67, s));
		col = mix(col, col * stain_c * 1.5, blob * min(stain_k, 1.2) * 0.6);
		col *= 1.0 - ring * min(stain_k, 1.2) * 0.3;
	}
	if (abs(wn.y) < 0.5) {
		if (base_dirt_k > 0.0) {
			// 벽 밑: 걸레질·신발에 묻은 때
			float d = 1.0 - smoothstep(0.0, 0.12 + 0.2 * nf.g, h_ref);
			col = mix(col, col * vec3(0.6, 0.56, 0.5), clamp(d * base_dirt_k, 0.0, 1.0));
		}
		if (hand_dirt_k > 0.0) {
			// 허리~가슴 높이 손때·가방 쓸린 자국
			float hb = smoothstep(0.7, 0.95, h_lvl) * (1.0 - smoothstep(1.25, 1.6, h_lvl));
			col *= 1.0 - hb * hand_dirt_k * smoothstep(0.3, 0.8, nf.b) * 0.22;
		}
		if (streaks_k > 0.0) {
			// 빗물 자국: 세로로 길게 늘인 노이즈
			float sv = texture(noise_tex, vec2(uv.x * 0.9, uv.y * 0.06) + vec2(0.7, 0.2)).g;
			col *= 1.0 - smoothstep(0.52, 0.78, sv) * (0.4 + 0.6 * nb.r) * streaks_k * 0.4;
		}
		if (damp_k > 0.0) {
			// 스며 오른 습기: 벽을 따라 들쭉날쭉한 높이까지 누렇게 어둡고, 끝에 마른 물때 선이 남는다
			float dh = damp_k * (0.55 + 0.9 * texture(noise_tex, vec2(uv.x / 2.9, 0.37)).g);
			float dz = 1.0 - smoothstep(dh - 0.12, dh, h_ref);
			float tide = smoothstep(dh - 0.05, dh - 0.01, h_ref) * (1.0 - smoothstep(dh - 0.01, dh + 0.02, h_ref));
			col = mix(col, col * vec3(0.66, 0.66, 0.56), dz * 0.75);
			col *= 1.0 - tide * 0.3;
		}
		if (leak_k > 0.0) {
			// 누수 자국: 천장(층 높이)에서 흘러내린 얼룩을 군데군데만 남긴다
			float lk = texture(leak_tex, vec2(uv.x / 3.3, (LEVEL_H - h_lvl) / 3.7)).r;
			float gate = smoothstep(0.5, 0.62, texture(noise_tex, uv / 17.0 + vec2(0.4, 0.9)).r);
			col = mix(col, col * mix(vec3(0.55, 0.5, 0.42), vec3(0.45, 0.25, 0.2), decay), lk * gate * min(leak_k, 1.0));
		}
	}
	if (shape_round < 0.5 && (edge_wear_k != 0.0 || edge_dirt_k > 0.0 || rust_k > 0.0)) {
		// 이 면에서 가장 가까운 박스 모서리까지 거리(m). 건물(월드 좌표)은 세로 모서리(벽 귀퉁이·문틀)만 본다
		vec3 dd = v_half - abs(v_lp);
		vec3 an = abs(v_ln);
		float de;
		if (an.y >= an.x && an.y >= an.z) {
			de = min(dd.x, dd.z);
		} else if (an.x >= an.z) {
			de = object_space > 0.5 ? min(dd.y, dd.z) : dd.z;
		} else {
			de = object_space > 0.5 ? min(dd.x, dd.y) : dd.x;
		}
		if (edge_wear_k != 0.0) {
			float we = (1.0 - smoothstep(0.003, 0.01 + 0.035 * nf.b, de)) * smoothstep(0.35, 0.65, nf.g + 0.2);
			if (edge_wear_k > 0.0) {
				col = mix(col, wear_color.rgb, clamp(we * edge_wear_k, 0.0, 1.0));
			} else {
				col *= 1.0 + we * edge_wear_k * 0.6;
			}
		}
		if (edge_dirt_k > 0.0) {
			// 바닥 판 가장자리(벽 밑)에 먼지·때가 쌓인다. 판은 벽 중심선까지 깔려 있어 0.1m는 벽 아래에 숨는다
			float dz = 1.0 - smoothstep(0.0, 0.18 + 0.25 * nf.g, de - 0.1);
			col *= 1.0 - dz * edge_dirt_k * 0.45;
		}
		if (rust_k > 0.0) {
			float bottom = 1.0 - smoothstep(0.0, 0.08 + 0.25 * nf.g, v_lp.y + v_half.y);
			float edge = 1.0 - smoothstep(0.0, 0.02 + 0.05 * nf.b, de);
			float rm = max(edge * 0.8, bottom) * smoothstep(0.35, 0.75, nf.r + nb.g * 0.3);
			col = mix(col, vec3(0.3, 0.15, 0.07) * (0.75 + 0.5 * nf.b), clamp(rm * rust_k, 0.0, 1.0));
		}
	}
	if (inst_var > 0.0) {
		col *= 1.0 + (v_seed - 0.5) * 2.0 * inst_var;
		col *= mix(vec3(1.0), vec3(1.04, 1.0, 0.95), (fract(v_seed * 13.7) - 0.5) * 4.0 * inst_var);
	}

	float rough = roughness;
	if (surf_scale > 0.0) {
		rough = clamp(rough * (1.12 - 0.24 * clamp(lum_d, 0.0, 1.5)), 0.04, 1.0);
	}
	if (wet_k > 0.0) {
		float wm = clamp(smoothstep(0.55, 0.7, nb.g * 0.6 + nf.r * 0.4) * wet_k, 0.0, 1.0);
		col *= 1.0 - wm * 0.35;
		rough = mix(rough, 0.1, wm);
	}
	if (surf_nrm_strength > 0.0 && surf_scale > 0.0) {
		vec2 nm = (texture(surf_nrm, st).rg * 2.0 - 1.0) * surf_nrm_strength;
		vec3 nw = normalize(U * nm.x + V * nm.y + N * sqrt(max(1.0 - dot(nm, nm), 0.0)));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = rough;
	METALLIC = metallic;
	if (emission_energy > 0.0) {
		EMISSION = col * emission_energy;
	}
}
