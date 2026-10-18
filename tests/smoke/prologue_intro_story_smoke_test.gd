extends SceneTree

# 프로젝트 벨카 - 프롤로그 도입(P-00 → P-01) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_intro_story_smoke_test.gd
# P-00 실종 몽타주 컷 순서, P-01 장부 회수 컷신(빠른 컷 · 선택지 세 번 · 같은 결말),
# 선택 결과 플래그, 연출 동작(잠금 · 권총 · 비상 버튼), 끝난 뒤 아지트로 이어지는지 검사한다.
# 두 번 진행한다: 첫 번째 선택지만 / 두 번째 선택지만.

const SCENE := "res://scenes/chapters/Prologue_Intro.tscn"
const CHOICE_LINES := ["prologue_p01_open", "prologue_p01_pistol", "prologue_p01_spare"]

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _scene: Node
var _choice_counts: Array[int] = []


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_gm = root.get_node("/root/GameManager")
	var sm: Node = root.get_node("/root/SceneManager")
	_check(sm.SCENE_NEW_GAME == SCENE, "새 게임은 프롤로그 도입부터 시작한다")
	_check(String((load(SCENE) as PackedScene).instantiate().get("next_scene")) == sm.SCENE_HIDEOUT, "도입이 끝나면 아지트로 간다")

	# 대사 데이터: 선택지는 세 군데, 각 두 개, 모두 같은 다음 장면으로 모인다
	for id in CHOICE_LINES:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/%s.json" % id))
		var choices: Array = []
		for line in data["lines"]:
			choices.append_array(line.get("choices", []))
		var all_exist := choices.size() == 2
		for c in choices:
			all_exist = all_exist and FileAccess.file_exists("res://data/dialogues/%s.json" % c["outcome"]["next_dialogue"])
		_check(all_exist, "%s: 선택지 두 개, 갈래 대사가 모두 있다" % id)

	await _play_through(0, {"p01_first": "lock", "p01_pistol": "pick", "p01_button": "warn"})
	await _play_through(1, {"p01_first": "server", "p01_pistol": "call", "p01_button": "cut"})

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _play_through(pick: int, expected: Dictionary) -> void:
	var tag := "[선택 %d] " % (pick + 1)
	_gm.reset_game_state()
	change_scene_to_file(SCENE)
	await _seconds(0.6)
	_scene = current_scene
	_scene.set("next_scene", "")
	var montage = _scene.get_node("IntroMontage")
	_check(montage.is_playing() and _scene.get_step() == 0 and _gm.is_exploration_locked(), tag + "시작하면 실종 몽타주가 나오고 움직일 수 없다")

	# --- P-00: 컷 순서 ---
	var kinds: Array[String] = []
	while montage.is_playing():
		var cut: int = montage.get_cut()
		if cut >= 0 and cut < montage.CUTS.size():
			kinds.append(String(montage.CUTS[cut][0]))
		await _seconds(0.4)
		montage.advance()
	_check(kinds == ["call", "crosswalk", "home", "garage", "news", "photos", "off"], tag + "통화 → 횡단보도 → 거실 → 주차장 → 뉴스 → 사진 → 꺼짐 (%s)" % [kinds])
	var stamps: Array = montage.CUTS.map(func(c): return String(c[2])).filter(func(s): return not s.is_empty())
	var places := {}
	for s in stamps:
		places[s.split(" · ")[1]] = true
	_check(places.size() == stamps.size() and stamps.size() >= 3, tag + "실종 장소·시각이 컷마다 다르다 (%s)" % [stamps])
	_check(_gm.get_story_flag("prologue_p00_seen", false), tag + "몽타주를 본 기록이 남는다")

	# --- P-01 여는 컷 ---
	await _seconds(0.5)
	_check(_scene.get_step() == 1 and _bars_shown(), tag + "P-01 은 레터박스 컷신으로 시작한다")
	_check(_scene.stamp_text().contains("사무실 뒷방"), tag + "장소 표기가 뜬다 (%s)" % _scene.stamp_text())
	var guard_b: Node3D = _scene.get_node("IntroRoom/GuardB")
	var waited := 0.0
	while not _dm.is_dialogue_active and waited < 15.0:
		await _seconds(0.2)
		waited += 0.2
	_check(absf(guard_b.rotation.z) > 1.2, tag + "샤무가 경호원을 제압한다 (쓰러짐)")
	_check(_scene.get_node("IntroRoom/Pistol").position.distance_to(_scene.GUN_SPOT) < 0.3, tag + "떨어진 권총이 책상 쪽으로 미끄러진다")
	_check(_dm.current_dialogue_id == "prologue_p01_open", tag + "사비가 들어오면 대화가 시작된다 (%s)" % _dm.current_dialogue_id)

	# --- 대사와 선택지 ---
	_choice_counts.clear()
	var guard := 0
	while _scene.get_step() < 5 and guard < 400:
		guard += 1
		if _dm.is_dialogue_active:
			await _advance(pick)
		else:
			await _seconds(0.2)
	_check(_choice_counts.size() == 3 and _choice_counts.all(func(n): return n == 2), tag + "선택지가 세 번, 매번 두 개씩 나온다 (%s)" % [_choice_counts])
	for key in expected:
		_check(String(_gm.get_story_flag(key, "")) == expected[key], tag + "선택 결과가 남는다: %s = %s" % [key, _gm.get_story_flag(key, "")])

	var room: Node = _scene.get_node("IntroRoom")
	_check(((room.get_node("LockLight") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.g > 0.8, tag + "전자식 잠금이 풀린다 (초록 불)")
	_check(room.get_node("Padlock").position.y < 0.2, tag + "기계식 자물쇠는 샤무가 부순다")
	_check(absf(room.get_node("CabinetHinge").rotation.y) > 1.0, tag + "보관함이 열린다")
	_check(not room.get_node("Pistol").visible, tag + "권총은 샤무가 탄창을 빼고 치운다")
	var button_red: float = ((room.get_node("ButtonLight") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.r
	_check((button_red < 0.3) == (expected["p01_button"] == "cut"), tag + "회선을 끊으면 비상 버튼 불이 꺼진다 (r=%.2f)" % button_red)

	# --- 퇴장과 마무리 ---
	var captions = _scene.get_node("CaptionSequence")
	waited = 0.0
	while not captions.is_playing() and waited < 20.0:
		await _seconds(0.2)
		waited += 0.2
	var sabi: Node3D = _scene.get_node("PlayerParty/Sabi")
	_check(sabi.global_position.z < 0.0, tag + "두 사람이 문밖으로 나간다 (%s)" % sabi.global_position)
	_check(captions.is_playing(), tag + "끝나면 '며칠 뒤' 자막이 나온다")
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_scene.get_step() == 6 and _gm.get_story_flag("prologue_p01_done", false), tag + "도입이 끝난다 (prologue_p01_done)")


## 대사를 한 줄 넘긴다. 선택지가 있으면 pick 번째를 고른다 (갈래 대사로 이어진다).
func _advance(pick: int) -> void:
	if _dm.get("_waiting_for_choice"):
		var choices: Array = _dm.get("_current_choices")
		_choice_counts.append(choices.size())
		_dm.choose_option(mini(pick, choices.size() - 1))
	else:
		_dm.show_next_line()
	await _seconds(0.25)


func _bars_shown() -> bool:
	var bars := _scene.get_node_or_null("CutsceneBars")
	return bars != null and (bars.get_node("Top") as ColorRect).offset_bottom > 1.0


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
