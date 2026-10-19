extends SceneTree

# 프로젝트 벨카 - 대화창 · 탐색 HUD 스모크 테스트 (기본 디자인 0.2 시안 02 · 03)
# 실행: godot --headless --path . -s res://tests/smoke/dialogue_hud_smoke_test.gd
# 탐색 HUD: 캐릭터 카드 두 장(조작 중 / 동행), 목표 칸 + 장소, 알림 카드(기록 갱신·규칙 위반), 무전 수신, 위 가운데 제한 시간.
# 대화창: 이름표(이름 + 역할), 초상화, 대화 중 HUD 흐려짐, 대화 기록(L로 열고 닫기, 선택한 답도 남는다),
#        자동 진행(켜면 손대지 않아도 다음 대사로), 선택지는 대화창 위에 놓인다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _settings: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_settings = root.get_node("/root/SettingsManager")
	root.get_node("/root/GameManager").set_story_flag("tutorial_defeat_done", true)
	var auto_before: bool = _settings.auto_advance()
	_settings.set_auto_advance(false)
	_open_chapter()
	for i in 8:
		await physics_frame
	await _frames(4)
	var hud: Node = current_scene.get_node("PrototypeHUD")
	var overlay: Control = hud.get("overlay")

	# --- 탐색 HUD ---
	var cards := overlay.find_children("*", "PanelContainer", true, false).filter(func(n): return n.get("stamina_text") != null)
	_check(cards.size() == 2, "왼쪽 위에 캐릭터 카드가 두 장 있다 (%d)" % cards.size())
	_check(cards.size() == 2 and cards[0].visible and cards[1].visible, "조작 중인 사람과 동행 카드가 모두 보인다")
	hud.show_notice("목표: 조회에 필요한 단서를 조사하세요.")
	_check(overlay.get_objective() == "조회에 필요한 단서를 조사하세요." and hud.objective_log.has("조회에 필요한 단서를 조사하세요."),
			"목표는 오른쪽 위 목표 칸에 고정되고 수첩 목표 기록에 남는다")
	var place_label: Label = overlay.get("_place")
	_check(place_label.visible and not place_label.text.is_empty(), "위 띠에 장소(구역)가 보인다 (%s)" % place_label.text)
	var before: int = overlay.notice_count()
	hud.show_notice("수첩에 기록됨 — 학교 안전 수칙", Color.WHITE, 5.0)
	await _frames(2)
	_check(overlay.notice_count() == before + 1, "규칙을 기록하면 오른쪽에 알림 카드가 뜬다")
	var texts := _texts(overlay.get("_notices"))
	# 시안 .hud-toast: 내용 한 줄에 "[Tab] 조사 기록에서 확인" 까지 이어 쓴다
	_check(texts.has("기록 갱신") and texts.has("학교 안전 수칙을 기록했습니다. [Tab] 조사 기록에서 확인"),
			"알림 카드: 기록 갱신 / 받침에 맞는 조사 / Tab 안내 (%s)" % ", ".join(texts))
	hud.show_notice("규칙 위반 [경고] 복도에서 뛰지 마세요", Color(1.0, 0.4, 0.35), 5.0)
	await _frames(2)
	_check(_texts(overlay.get("_notices")).has("규칙 위반"), "규칙 위반은 '규칙 위반' 머리말 카드로 뜬다")
	for i in 4:
		hud.show_notice("알림 %d" % i, Color.WHITE, 5.0)
	await _frames(2)
	_check(overlay.notice_count() <= 3, "알림 카드는 세 장까지만 쌓인다 (%d)" % overlay.notice_count())
	hud.radio("sabi", "기록과 다르면 바로 알려줘.")
	var radio_box: Node = hud.get_node("RadioFeed")
	_check(radio_box.get_child_count() == 1 and _texts(radio_box).has("무전 수신"), "무전은 아래 가운데 '무전 수신' 칸으로 뜬다")
	hud.set_timer("bell", "다음 종까지", 204.0)
	_check(hud.get_timer_text("bell") == "다음 종까지  03:24", "위 가운데에 남은 시간이 보인다 (%s)" % hud.get_timer_text("bell"))
	hud.clear_timer("bell")
	_check(hud.get_timer_text("bell") == "", "제한 시간을 지우면 사라진다")

	# --- 대화창: 이름표 · 초상화 · HUD 흐려짐 ---
	var box: CanvasLayer = current_scene.get_node("DialogueBox")
	var start_count: int = box.history.size()
	_dm.start_dialogue_data("dlg_test", [
		{"speaker": "sabi", "speaker_name": "사비 아사기", "sabi_emotion": "serious", "text": "샤무, 이름표 봐."},
		{"speaker": "shamu", "speaker_name": "카즈네 샤무", "text": "번호가 같네."},
		{"speaker": "system", "text": "복도 끝에서 종이 울린다."},
		{"speaker": "sabi", "speaker_name": "사비 아사기", "text": "어떻게 할까?",
			"choices": [{"text": "기록을 먼저 대조한다."}, {"text": "샤무와 함께 주변을 확인한다."}]},
	])
	await _frames(3)
	_check(box.get("root_container").visible, "대화가 시작되면 대화창이 뜬다")
	_check(String(box.get("speaker_label").text) == "사비 아사기" and String(box.get("_role_label").text) == "관찰 · 분석",
			"이름표에 이름과 역할이 보인다 (%s / %s)" % [box.get("speaker_label").text, box.get("_role_label").text])
	_check(box.get("_portrait_frame").visible and box.get("_portrait").texture != null, "말하는 사람의 초상화가 보인다")
	await _seconds(0.4)
	_check(hud.get("_dialogue_fade").modulate.a < 0.05, "대화 중에는 탐색 HUD가 흐려진다")

	# 자동 진행: 켜면 손대지 않아도 다음 대사로
	_settings.set_auto_advance(true)
	box.call("_refresh_auto_button")
	_check(String(box.get("_auto_button").text) == "자동 켜짐", "자동 진행 버튼이 '자동 켜짐'으로 바뀐다")
	box.call("_finish_typing")
	var waited := 0.0
	while waited < box.AUTO_MAX + 0.5 and String(box.get("speaker_label").text) == "사비 아사기":
		await _seconds(0.1)
		waited += 0.1
	_settings.set_auto_advance(false)
	_check(String(box.get("speaker_label").text) == "카즈네 샤무" and waited >= box.AUTO_MIN - 0.2,
			"자동 진행을 켜면 잠시 뒤(%.1f초) 다음 대사로 넘어간다" % waited)
	_check(String(box.get("_role_label").text) == "돌파 · 보호", "샤무 이름표에는 '돌파 · 보호'")
	box.call("_refresh_auto_button")
	_check(String(box.get("_auto_button").text) == "자동 꺼짐", "다시 누르면 '자동 꺼짐'")

	# 대화 기록 (L)
	_press("dialogue_log")
	await _frames(3)
	_check(box.is_log_open(), "L을 누르면 대화 기록이 열린다")
	var log_texts := _rich_texts(box.get("_log_list"))
	_check(log_texts.has("샤무, 이름표 봐.") and log_texts.has("번호가 같네."), "대화 기록에 지나온 대사가 남아 있다")
	var line_before := String(box.get("speaker_label").text)
	_press("interact")
	await _frames(3)
	_check(box.is_log_open() and String(box.get("speaker_label").text) == line_before, "대화 기록이 열려 있는 동안에는 대사가 넘어가지 않는다")
	_press("dialogue_log")
	await _frames(3)
	_check(not box.is_log_open(), "L을 다시 누르면 대화 기록이 닫힌다")

	# 서술 → 선택지
	_advance()
	await _frames(3)
	_check(not box.get("_name_tag").visible and not box.get("_portrait_frame").visible, "서술은 이름표·초상화 없이 나온다")
	_advance()
	await _frames(3)
	box.call("_finish_typing")
	await _frames(2)
	var choices: VBoxContainer = box.get("choices_container")
	var panel: Panel = box.get("text_panel")
	_check(choices.visible and choices.get_child_count() == 2, "선택지 두 개가 뜬다")
	_check(choices.get_global_rect().end.y < panel.get_global_rect().position.y, "선택지는 대화창 위에 놓인다")
	(choices.get_child(0) as Button).pressed.emit()
	await _frames(3)
	var last: Dictionary = box.history[-1] if not box.history.is_empty() else {}
	_check(String(last.get("text", "")) == "기록을 먼저 대조한다.", "고른 답도 대화 기록에 남는다")
	_check(box.history.size() - start_count == 5, "대화 기록: 대사 네 줄 + 고른 답 하나 (%d)" % (box.history.size() - start_count))
	if _dm.is_dialogue_active:
		_dm.abort_dialogue()
		_dm.dialogue_completed.emit("dlg_test")
	await _seconds(0.4)
	_check(hud.get("_dialogue_fade").modulate.a > 0.95, "대화가 끝나면 탐색 HUD가 다시 보인다")

	_settings.set_auto_advance(auto_before)
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  - ", f)
	quit(1 if _failures.size() > 0 else 0)


func _advance() -> void:
	var box: CanvasLayer = current_scene.get_node("DialogueBox")
	if box.get("_is_typing"):
		box.call("_finish_typing")
	_dm.show_next_line()


## node 아래 Label 글자 전부
func _texts(node: Node) -> Array:
	var out := []
	for l in node.find_children("*", "Label", true, false):
		out.append(String(l.text))
	return out


func _rich_texts(node: Node) -> Array:
	var out := []
	for l in node.find_children("*", "RichTextLabel", true, false):
		out.append(String(l.text))
	return out


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _seconds(duration: float) -> void:
	await create_timer(duration, true).timeout


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


## 학교 챕터를 이야기 없이(run_story=false) 연다
func _open_chapter() -> void:
	var old := current_scene
	var scene: Node = (load(CHAPTER) as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	if old:
		old.queue_free()
