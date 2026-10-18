class_name IntroMontage
extends CanvasLayer

# 프로젝트 벨카 - P-00 "사라지는 사람들" 도입 몽타주
# 서로 다른 날·다른 장소의 평범한 실종을 짧은 컷으로 잘라 보여 준다 (관객에게만 큰 현상을 암시).
# 실종 장소·시각을 하나로 모으지 않고, 특정 얼굴을 지우거나 공장 좌표를 겹쳐 띄우지 않는다.
# 일러스트 배경과 독립된 인물을 겹친다. 에셋이 없으면 기존 도형 연출로 돌아간다.
#   play()  : 컷을 차례로 보여 주고 끝나면 finished
#   E / Enter 로 다음 컷, 컷 사이에는 짧은 노이즈 (화면 효과 줄이기에서는 끈다)
# 설계: 기획서/05.스토리/게임 시나리오/프롤로그_도입_개정.md

signal finished()
signal cut_changed(index: int, kind: String)

const LOCK_REASON := "intro_montage"
const CALL_LINE := "응, 거의 다 왔어. 횡단보도만 건너면—"
const NEWS_LINES := [
	"최근 접수된 실종 사건들에 대해 경찰이 수사를 이어가고 있습니다.",
	"사건 사이의 연관성은 아직 확인되지 않았습니다.",
]
## [종류, 길이(초), 장소 표기]
const CUTS := [
	["call", 4.4, ""],
	["crosswalk", 3.4, "수요일 18:52 · 횡단보도"],
	["home", 3.4, "금요일 07:30 · 아파트 거실"],
	["garage", 4.4, "일요일 22:14 · 지하주차장"],
	["news", 6.0, ""],
	["photos", 3.0, ""],
	["off", 1.0, ""],
]
## 다음 컷으로 넘기는 입력은 컷이 시작되고 이만큼 지나야 받는다 (연타로 전부 넘어가지 않게)
const MIN_CUT_SECONDS := 0.35
const NOISE_SECONDS := 0.09

var _canvas: Control
var _font: Font
var _index: int = -1
var _t: float = 0.0
var _noise_left: float = 0.0
var _playing: bool = false
var _beep_left: float = 0.0
var _dropped: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 85
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.visible = false
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	_font = _canvas.get_theme_default_font()
	_rng.seed = 208


func is_playing() -> bool:
	return _playing


## 지금 컷 번호 (테스트용)
func get_cut() -> int:
	return _index


func play() -> void:
	_playing = true
	_canvas.visible = true
	GameManager.set_exploration_lock(LOCK_REASON, true)
	_index = -1
	advance()


## 다음 컷으로 (마지막 컷 다음이면 끝낸다)
func advance() -> void:
	if not _playing:
		return
	_index += 1
	_t = 0.0
	_dropped = false
	_beep_left = 0.0
	if _index >= CUTS.size():
		_finish()
		return
	if not _reduce_effects() and _index > 0:
		_noise_left = NOISE_SECONDS
		SfxBank.play(self, "static", -22.0, 1.4)
	var kind: String = CUTS[_index][0]
	if kind == "home":
		SfxBank.play(self, "static", -30.0, 0.6)
	elif kind == "off":
		SfxBank.play(self, "static", -20.0, 0.8)
	cut_changed.emit(_index, kind)
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not _playing or _index < 0:
		return
	_t += delta
	_noise_left = maxf(0.0, _noise_left - delta)
	if _reduce_effects():
		_noise_left = 0.0
	var kind: String = CUTS[_index][0]
	if kind == "call" and not _dropped and _t >= 3.0:
		_dropped = true
		SfxBank.play(self, "call_drop", -10.0)
	if kind == "crosswalk":
		_beep_left -= delta
		if _beep_left <= 0.0:
			_beep_left = 0.55
			SfxBank.play(self, "ui_tick", -18.0, 0.55)
	_canvas.queue_redraw()
	if _t >= float(CUTS[_index][1]):
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _t < MIN_CUT_SECONDS:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func _finish() -> void:
	_playing = false
	_canvas.visible = false
	GameManager.set_exploration_lock(LOCK_REASON, false)
	finished.emit()


func _reduce_effects() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.reduce_effects()


# ------------------------------------------------------------------ 그리기

func _on_draw() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _index < 0 or _index >= CUTS.size():
		return
	var k := size.y / 1080.0
	var kind: String = CUTS[_index][0]
	match kind:
		"call": _draw_call(size, k)
		"crosswalk": _draw_crosswalk(size, k)
		"home": _draw_home(size, k)
		"garage": _draw_garage(size, k)
		"news": _draw_news(size, k)
		"photos": _draw_photos(size, k)
		"off": _draw_off(size, k)
	if kind in ["crosswalk", "home", "garage", "photos"]:
		_draw_film_edges(size, k)
	var stamp: String = CUTS[_index][2]
	if not stamp.is_empty():
		_draw_stamp(stamp, k)
	_text("E / Enter  다음", Vector2(size.x - 200 * k, size.y - 40 * k), 15 * k, Color(0.5, 0.53, 0.57))
	if _noise_left > 0.0:
		_draw_noise(size, k)


func _text(s: String, pos: Vector2, font_size: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_canvas.draw_string(_font, pos, s, align, width, int(font_size), color)


func _draw_stamp(stamp: String, k: float) -> void:
	var a := 1.0 if _reduce_effects() else clampf(_t / 0.25, 0.0, 1.0)
	var x := 64 * k - (1.0 - a) * 24 * k
	_canvas.draw_rect(Rect2(x, 58 * k, 4 * k, 34 * k), Color(VelkaStyle.SABI, a))
	_text(stamp, Vector2(x + 18 * k, 86 * k), 24 * k, Color(0.9, 0.92, 0.94, a))


## 장소와 다음 컷 안내가 밝은 그림 위에서도 읽히도록 가장자리만 어둡게 한다.
func _draw_film_edges(size: Vector2, k: float) -> void:
	for i in 10:
		var alpha := 0.034 * float(10 - i)
		_canvas.draw_rect(Rect2(0, i * 12 * k, size.x, 12 * k), Color(0.01, 0.015, 0.02, alpha))
		_canvas.draw_rect(Rect2(0, size.y - (i + 1) * 10 * k, size.x, 10 * k), Color(0.01, 0.015, 0.02, alpha))


func _draw_noise(size: Vector2, k: float) -> void:
	for i in 70:
		var y := _rng.randf() * size.y
		var h := _rng.randf_range(1.0, 7.0) * k
		var x := _rng.randf() * size.x * 0.6
		_canvas.draw_rect(Rect2(x, y, _rng.randf_range(0.2, 0.6) * size.x, h), Color(1, 1, 1, _rng.randf_range(0.05, 0.3)))


## 검은 화면 위의 통화: 말이 끝나기 전에 끊긴다
func _draw_call(size: Vector2, k: float) -> void:
	var c := size * 0.5
	var shown := mini(CALL_LINE.length(), int(_t * 14.0))
	var line := CALL_LINE.substr(0, shown)
	var cut_at := 3.0
	var dot_color := Color(0.35, 0.8, 0.5) if _t < cut_at else Color(0.75, 0.3, 0.28)
	_canvas.draw_circle(Vector2(c.x - 92 * k, c.y - 96 * k), 6 * k, dot_color)
	var seconds := 41 + int(minf(_t, cut_at))
	_text("통화 중  00:%02d" % seconds if _t < cut_at else "통화 종료  00:%02d" % seconds,
			Vector2(c.x - 76 * k, c.y - 88 * k), 20 * k, Color(0.6, 0.63, 0.66))
	_text("여성", Vector2(c.x - 420 * k, c.y - 18 * k), 22 * k, Color(0.55, 0.58, 0.62))
	_text("“" + line + ("”" if shown >= CALL_LINE.length() else ""), Vector2(c.x - 420 * k, c.y + 26 * k), 34 * k,
			Color(0.92, 0.93, 0.95, 1.0 if _t < cut_at else 0.35))
	if _t >= cut_at:
		_text("뚝—", Vector2(c.x - 420 * k, c.y + 110 * k), 26 * k, Color(0.75, 0.3, 0.28))


## 저녁 횡단보도: 신호는 깜빡이고, 길가에 휴대전화만 남아 있다
func _draw_crosswalk(size: Vector2, k: float) -> void:
	var road := Rect2(0, size.y * 0.24, size.x, size.y * 0.5)
	var illustrated := VelkaCinematicArt.draw_plate(_canvas, Rect2(Vector2.ZERO, size), 0)
	if not illustrated:
		_draw_crosswalk_fallback(size, k, road)
	# 한 사람이 사라진 뒤의 흔적. 이미지를 바꿔도 전화 화면은 선명하게 남는다.
	var phone := Vector2(size.x * 0.6, size.y * 0.82)
	_canvas.draw_circle(phone, 90 * k, Color(0.5, 0.7, 0.9, 0.06))
	_canvas.draw_set_transform(phone, deg_to_rad(-16), Vector2(0.72, 0.28))
	_canvas.draw_rect(Rect2(-44 * k, -80 * k, 88 * k, 160 * k), Color(0.03, 0.03, 0.04))
	_canvas.draw_rect(Rect2(-38 * k, -72 * k, 76 * k, 144 * k), Color(0.36, 0.5, 0.62))
	_canvas.draw_string(_font, Vector2(-32 * k, -30 * k), "통화 종료", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(0.95, 0.96, 0.98))
	_canvas.draw_string(_font, Vector2(-32 * k, -10 * k), "00:44", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(0.85, 0.88, 0.92))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_crosswalk_fallback(size: Vector2, k: float, road: Rect2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.1))
	_canvas.draw_rect(road, Color(0.13, 0.135, 0.15))
	_canvas.draw_rect(Rect2(0, road.end.y, size.x, 10 * k), Color(0.3, 0.3, 0.32))
	_canvas.draw_rect(Rect2(0, road.end.y + 10 * k, size.x, size.y), Color(0.17, 0.17, 0.19))
	var x := size.x * 0.3
	while x < size.x * 0.72:
		_canvas.draw_rect(Rect2(x, road.position.y + 14 * k, 58 * k, road.size.y - 28 * k), Color(0.78, 0.79, 0.8, 0.85))
		x += 104 * k
	# 지나가는 차의 불빛
	var sweep := fmod(_t * 0.9, 2.2)
	if sweep < 1.0 and not _reduce_effects():
		var sx := lerpf(-0.4, 1.2, sweep) * size.x
		_canvas.draw_rect(Rect2(sx, road.position.y, size.x * 0.25, road.size.y), Color(1.0, 0.92, 0.7, 0.07))
	# 보행 신호
	var green_on := _reduce_effects() or fmod(_t, 0.6) < 0.3
	_canvas.draw_rect(Rect2(size.x * 0.82, size.y * 0.08, 46 * k, 92 * k), Color(0.05, 0.05, 0.06))
	_canvas.draw_circle(Vector2(size.x * 0.82 + 23 * k, size.y * 0.08 + 68 * k), 14 * k,
			Color(0.3, 0.95, 0.55) if green_on else Color(0.1, 0.2, 0.14))
	_canvas.draw_circle(Vector2(size.x * 0.82 + 23 * k, size.y * 0.08 + 24 * k), 14 * k, Color(0.2, 0.06, 0.05))


## 아침 거실: 켜진 텔레비전, 식탁의 음식, 현관의 신발. 서둘러 떠난 흔적은 없다.
func _draw_home(size: Vector2, k: float) -> void:
	if VelkaCinematicArt.draw_plate(_canvas, Rect2(Vector2.ZERO, size), 1):
		return
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.12, 0.12))
	_canvas.draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color(0.2, 0.17, 0.14))
	# 텔레비전
	var tv := Rect2(size.x * 0.66, size.y * 0.26, size.x * 0.24, size.y * 0.26)
	var flicker := 0.85 if _reduce_effects() else 0.85 + 0.15 * sin(_t * 23.0) * sin(_t * 7.0)
	_canvas.draw_rect(tv.grow(12 * k), Color(0.04, 0.04, 0.05))
	_canvas.draw_rect(tv, Color(0.32 * flicker, 0.42 * flicker, 0.58 * flicker))
	var y := tv.position.y
	while y < tv.end.y:
		_canvas.draw_line(Vector2(tv.position.x, y), Vector2(tv.end.x, y), Color(0, 0, 0, 0.12), 1.0)
		y += 4 * k
	_canvas.draw_rect(Rect2(tv.position.x - tv.size.x * 0.3, size.y * 0.7, tv.size.x * 1.6, size.y * 0.3), Color(0.4, 0.5, 0.7, 0.05 * flicker))
	# 식탁과 음식
	var table := Rect2(size.x * 0.28, size.y * 0.58, size.x * 0.3, 22 * k)
	_canvas.draw_rect(table, Color(0.35, 0.26, 0.18))
	_canvas.draw_rect(Rect2(table.position.x + 20 * k, table.end.y, 16 * k, size.y * 0.16), Color(0.25, 0.18, 0.13))
	_canvas.draw_rect(Rect2(table.end.x - 36 * k, table.end.y, 16 * k, size.y * 0.16), Color(0.25, 0.18, 0.13))
	var bowl := Vector2(table.get_center().x - 60 * k, table.position.y - 18 * k)
	_canvas.draw_rect(Rect2(bowl.x - 44 * k, bowl.y - 6 * k, 88 * k, 24 * k), Color(0.86, 0.84, 0.8))
	_canvas.draw_circle(Vector2(bowl.x + 120 * k, bowl.y + 4 * k), 22 * k, Color(0.82, 0.8, 0.76))
	_canvas.draw_line(Vector2(bowl.x + 50 * k, bowl.y + 16 * k), Vector2(bowl.x + 92 * k, bowl.y - 2 * k), Color(0.7, 0.68, 0.62), 3 * k)
	# 김이 오른다 (아직 따뜻하다)
	for i in 3:
		var pts := PackedVector2Array()
		for j in 12:
			var f := float(j) / 11.0
			var drift := 0.0 if _reduce_effects() else _t * 2.2
			pts.append(Vector2(bowl.x - 20 * k + i * 20 * k + sin(f * 6.0 + drift + i) * 6 * k, bowl.y - 12 * k - f * 90 * k))
		_canvas.draw_polyline(pts, Color(1, 1, 1, 0.12), 2 * k)
	# 현관의 신발 한 켤레 (가지런하다)
	var mat := Rect2(size.x * 0.06, size.y * 0.82, size.x * 0.14, 18 * k)
	_canvas.draw_rect(mat, Color(0.3, 0.27, 0.24))
	for i in 2:
		_canvas.draw_rect(Rect2(mat.position.x + 40 * k + i * 70 * k, mat.position.y - 20 * k, 56 * k, 22 * k), Color(0.12, 0.12, 0.14))


## 지하주차장 CCTV 두 대: 한쪽에 들어온 사람이 다음 카메라에는 나타나지 않는다
func _draw_garage(size: Vector2, k: float) -> void:
	var backdrop := Color(0.025, 0.035, 0.04)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), backdrop)
	var gap := 24 * k
	var w := (size.x - 160 * k - gap) * 0.5
	var h := w * 9.0 / 16.0
	var top := (size.y - h) * 0.5 + 30 * k
	for cam in 2:
		var r := Rect2(80 * k + cam * (w + gap), top, w, h)
		if not VelkaCinematicArt.draw_plate(_canvas, r, 2, Color(0.64, 0.74, 0.69)):
			_draw_garage_fallback(r, k)
		if cam == 0:
			# 사람이 지나가 화면 오른쪽 출구로 나간다
			var f := clampf((_t - 0.3) / 2.2, 0.0, 1.0)
			if f > 0.0 and f < 1.0:
				var px := lerpf(r.position.x + r.size.x * 0.25, r.end.x + 30 * k, f)
				var py := r.end.y - r.size.y * 0.14
				var bob := 0.0 if _reduce_effects() else sin(f * 40.0) * 2 * k
				if not VelkaCinematicArt.draw_person(_canvas, Vector2(px, py + bob), r.size.y * 0.56, 8, Color(0.72, 0.78, 0.73), r):
					_canvas.draw_rect(Rect2(px - 14 * k, py - 96 * k + bob, 28 * k, 84 * k), Color(0.05, 0.06, 0.05))
					_canvas.draw_circle(Vector2(px, py - 108 * k + bob), 14 * k, Color(0.05, 0.06, 0.05))
				# 인물이 화면 밖으로 걸어 나갈 때 옆 영상으로 새지 않게 가린다.
				_canvas.draw_rect(Rect2(r.end.x, r.position.y, 100 * k, r.size.y), backdrop)
		# 화면 정보
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 52 * k)), Color(0.015, 0.025, 0.02, 0.6))
		var stamp := "22:14:%02d" % (int(_t) + (6 if cam == 0 else 9))
		_text("CAM 0%d · B2%s" % [3 + cam, "" if cam == 0 else " 출구"], r.position + Vector2(16 * k, 34 * k), 20 * k, Color(0.85, 0.9, 0.86))
		_text(stamp, Vector2(r.end.x - 130 * k, r.position.y + 34 * k), 20 * k, Color(0.85, 0.9, 0.86))
		if _reduce_effects() or fmod(_t, 1.0) < 0.6:
			_canvas.draw_circle(Vector2(r.end.x - 150 * k, r.position.y + 27 * k), 6 * k, Color(0.9, 0.2, 0.2))
		var y := r.position.y
		while y < r.end.y:
			_canvas.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.18), 1.0)
			y += 3 * k
		_canvas.draw_rect(r, Color(0.24, 0.32, 0.31), false, k)
		_text("연결 통로" if cam == 0 else "출입구 · 다음 카메라", Vector2(r.position.x, r.end.y + 38 * k), 19 * k, Color(0.52, 0.61, 0.59))


func _draw_garage_fallback(r: Rect2, k: float) -> void:
	_canvas.draw_rect(r, Color(0.16, 0.19, 0.17))
	var vanish := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.38)
	for i in 5:
		var fx := r.position.x + r.size.x * (0.1 + 0.2 * i)
		_canvas.draw_line(Vector2(fx, r.end.y), vanish, Color(0.4, 0.45, 0.42, 0.5), 2 * k)
	_canvas.draw_rect(Rect2(r.position.x + r.size.x * 0.08, r.position.y + r.size.y * 0.12, r.size.x * 0.06, r.size.y * 0.7), Color(0.27, 0.3, 0.28))
	_canvas.draw_rect(Rect2(r.end.x - r.size.x * 0.16, r.position.y + r.size.y * 0.12, r.size.x * 0.07, r.size.y * 0.7), Color(0.27, 0.3, 0.28))
	_canvas.draw_rect(Rect2(r.position.x + r.size.x * 0.2, r.end.y - r.size.y * 0.3, r.size.x * 0.2, r.size.y * 0.16), Color(0.11, 0.13, 0.12))


## 뉴스: 두 줄. 사건 사이의 연관성은 확인되지 않았다.
func _draw_news(size: Vector2, k: float) -> void:
	if not VelkaCinematicArt.draw_plate(_canvas, Rect2(Vector2.ZERO, size), 3, Color(0.26, 0.34, 0.43)):
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.14))
	for i in 9:
		var y := size.y * (0.1 + 0.08 * i)
		_canvas.draw_line(Vector2(0, y), Vector2(size.x, y + 40 * k), Color(0.2, 0.3, 0.5, 0.08), 2 * k)
	_canvas.draw_rect(Rect2(64 * k, 60 * k, 120 * k, 40 * k), Color(0.75, 0.16, 0.14))
	_text("뉴스", Vector2(98 * k, 90 * k), 24 * k, Color.WHITE)
	var bar := Rect2(0, size.y * 0.7, size.x, 120 * k)
	_canvas.draw_rect(bar, Color(0.93, 0.94, 0.96))
	_canvas.draw_rect(Rect2(0, bar.position.y, 18 * k, bar.size.y), Color(0.75, 0.16, 0.14))
	var which := 0 if _t < 3.0 else 1
	var local := _t - which * 3.0
	var line: String = NEWS_LINES[which]
	_text(line.substr(0, mini(line.length(), int(local * 24.0))), Vector2(64 * k, bar.position.y + 72 * k), 36 * k, Color(0.08, 0.09, 0.12))
	var ticker := Rect2(0, bar.end.y, size.x, 46 * k)
	_canvas.draw_rect(ticker, Color(0.1, 0.12, 0.18))
	var crawl := "실종자 가족 지원 창구 안내  ·  목격하신 분은 가까운 경찰서로 연락 바랍니다  ·  "
	var tx := 64.0 * k if _reduce_effects() else size.x - fmod(_t * 160.0 * k, size.x + 1400 * k)
	_text(crawl, Vector2(tx, ticker.position.y + 32 * k), 22 * k, Color(0.82, 0.85, 0.9))


## 사진 여러 장이 짧게 지나간다 (평범한 사진들, 얼굴을 지우거나 좌표를 겹치지 않는다)
func _draw_photos(size: Vector2, k: float) -> void:
	if not VelkaCinematicArt.draw_plate(_canvas, Rect2(Vector2.ZERO, size), 3, Color(0.52, 0.52, 0.52)):
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.07))
	var tints := [Color(0.55, 0.62, 0.7), Color(0.7, 0.6, 0.48), Color(0.5, 0.62, 0.5), Color(0.66, 0.55, 0.6), Color(0.6, 0.6, 0.56)]
	var hairs := [Color(0.1, 0.08, 0.07), Color(0.3, 0.2, 0.12), Color(0.15, 0.13, 0.12), Color(0.45, 0.4, 0.36), Color(0.08, 0.08, 0.1)]
	# 협회 인물이 아닌 서로 다른 평범한 시민 세 명의 사진이다.
	for i in 3:
		var appear := i * 0.38
		if _t < appear:
			break
		var f := clampf((_t - appear) / 0.18, 0.0, 1.0)
		var center := Vector2(size.x * (0.29 + 0.21 * i), size.y * (0.48 + (0.05 if i % 2 == 0 else -0.04)))
		if not _reduce_effects():
			center.y += (1.0 - f) * 60 * k
		_canvas.draw_set_transform(center, deg_to_rad(-7 + i * 6.0), Vector2.ONE)
		var card := Rect2(-150 * k, -190 * k, 300 * k, 380 * k)
		_canvas.draw_rect(Rect2(card.position + Vector2(9 * k, 12 * k), card.size), Color(0.0, 0.0, 0.0, 0.3 * f))
		_canvas.draw_rect(card, Color(0.93, 0.92, 0.89, f))
		var pic := Rect2(card.position + Vector2(16 * k, 16 * k), Vector2(268 * k, 290 * k))
		_canvas.draw_rect(pic, Color(tints[i], f))
		if not VelkaCinematicArt.draw_portrait(_canvas, pic, 6 + i, Color(1.0, 1.0, 1.0, f)):
			var head := pic.get_center() + Vector2(0, -20 * k)
			_canvas.draw_rect(Rect2(head.x - 70 * k, head.y + 50 * k, 140 * k, pic.end.y - head.y - 50 * k), Color(0.2 + 0.05 * i, 0.22, 0.26, f))
			_canvas.draw_circle(head, 44 * k, Color(0.86, 0.74, 0.64, f))
			_canvas.draw_rect(Rect2(head.x - 46 * k, head.y - 48 * k, 92 * k, 30 * k), Color(hairs[i], f))
		_canvas.draw_line(Vector2(card.position.x + 22 * k, card.end.y - 39 * k), Vector2(card.end.x - 70 * k, card.end.y - 39 * k), Color(0.4, 0.4, 0.38, 0.35 * f), k)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 화면이 꺼진다
func _draw_off(size: Vector2, k: float) -> void:
	if _reduce_effects():
		return
	var f := clampf(_t / 0.6, 0.0, 1.0)
	var c := size * 0.5
	var w := lerpf(size.x, 6 * k, f)
	var h := lerpf(10 * k, 3 * k, f)
	_canvas.draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), Color(0.9, 0.95, 1.0, 1.0 - f * 0.6))
