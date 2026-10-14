extends SceneTree

# 프로젝트 벨카 - 수첩(Journal) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/journal_smoke_test.gd
# Tab으로 열고 닫기(탐색 잠금), 탭 전환, 문서가 flag·규칙 발견으로 열리는 것, 새 쪽 알림,
# 무진고 수칙서 렌더링, 협회 기록 규칙이 "확인됨"으로 보이지 않는 것, 인벤토리 목록을 검사한다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _rm: Node
var _inv: Node
var _journal: Node
var _notices: Array[String] = []


## HUD 대신 알림을 받아 적는 가짜 리스너
class NoticeSink extends Node:
	var sink: Array[String]

	func show_notice(text: String, _color: Color = Color.WHITE, _seconds: float = 3.0) -> void:
		sink.append(text)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	_rm = root.get_node("/root/RuleManager")
	_inv = root.get_node("/root/InventoryManager")
	_open_chapter()
	for i in 4:
		await physics_frame
	_journal = current_scene.get_node("Journal")
	var sink := NoticeSink.new()
	sink.sink = _notices
	sink.add_to_group("rule_warning_listener")
	root.add_child(sink)

	# --- 열기 / 닫기 ---
	_check(_journal != null and not _journal.is_open(), "수첩은 처음에 닫혀 있다")
	_press("journal")
	await _input_frames()
	_check(_journal.is_open() and _gm.is_exploration_locked(), "Tab으로 수첩이 열리고 그동안 움직일 수 없다")
	_press("journal")
	await _input_frames()
	_check(not _journal.is_open() and not _gm.is_exploration_locked(), "Tab을 다시 누르면 닫히고 잠금이 풀린다")
	_journal.open()
	await _input_frames()
	_press_key(KEY_ESCAPE)
	await _input_frames()
	_check(not _journal.is_open() and not _gm.is_exploration_locked(), "Esc로 닫힌다")
	_gm.set_exploration_lock("test_cutscene", true)
	_press("journal")
	await _input_frames()
	_check(not _journal.is_open(), "컷신 같은 다른 잠금 중에는 열리지 않는다")
	_gm.set_exploration_lock("test_cutscene", false)

	# --- 문서는 flag 가 서기 전까지 보이지 않는다 ---
	_check(_journal.get_documents("report").is_empty() and _journal.get_documents("rulebook").is_empty(), "처음에는 보고서·수칙서 문서가 없다")
	_journal.open()
	await _input_frames()
	var empty_label: Label = _journal.get("_empty_label")
	_check(empty_label.visible and String(empty_label.text).contains("아직"), "문서가 없으면 빈 상태 문구가 보인다")
	_journal.close()

	_notices.clear()
	_gm.set_story_flag("sh_p08_done", true)
	await _input_frames()
	_check(_ids(_journal.get_documents("report")) == ["assoc_basic"], "sh_p08_done 이후 '괴이저항단체 기초 안내'가 보고서에 생긴다")
	_check(_notices.any(func(t): return t.contains("수첩에 새 문서") and t.contains("괴이저항단체 기초 안내")), "새 문서가 열리면 HUD에 알린다")
	_gm.set_story_flag("prologue_done", true)
	await _input_frames()
	_check(_journal.is_document_unlocked("school_report"), "prologue_done 이후 학교 구역 보고서가 열린다")
	var report_pages: int = _journal.get_pages("school_report").size()
	_check(report_pages >= 2 and report_pages < 8, "학교 보고서는 아는 사고 기록 쪽만 열린다 (%d쪽)" % report_pages)
	_check(not _journal.is_document_unlocked("subway_rules") and not _journal.is_document_unlocked("school_rulebook"), "수칙서는 아직 없다")
	_gm.set_story_flag("dlg_c1_subway", true)
	await _input_frames()
	_check(_ids(_journal.get_documents("rulebook")) == ["subway_rules"], "지하철 장면이 시작되면 지하철 이동 수칙이 생긴다")
	_notices.clear()
	_gm.set_story_flag("c1_arrival_done", true)
	await _input_frames()
	_check(_ids(_journal.get_documents("rulebook")) == ["subway_rules", "school_rulebook"], "학교에 도착하면 무진고 안전수칙서가 생긴다")

	# --- 규칙 발견으로 쪽이 추가된다 ---
	var rule_pages: int = _journal.get_pages("school_rulebook").size()
	_check(rule_pages == 2, "도착 직후 수칙서는 이미 아는 서문·공통 / 안내문 확인 쪽만 있다 (%d쪽)" % rule_pages)
	_notices.clear()
	var report_before: int = _journal.get_pages("school_report").size()
	_rm.discover_rule("RULE_CAFETERIA_01", "inspect", "sabi")
	await _input_frames()
	_check(_journal.get_pages("school_rulebook").size() == rule_pages + 1, "급식실 수칙을 알게 되면 수칙서에 급식실 쪽이 추가된다")
	_check(_journal.get_pages("school_report").size() == report_before + 1, "같은 구역의 협회 보고서 사고 기록도 열린다")
	_check(_notices.any(func(t): return t.contains("수첩에 새 페이지")), "새 쪽이 열리면 HUD에 알린다")

	# --- 탭 전환 ---
	_journal.open()
	await _input_frames()
	_check(_journal.get_tab() == 2, "새 쪽이 있으면 그 탭부터 열린다 (협회 보고서)")
	_press_key(KEY_E)
	await _input_frames()
	_check(_journal.get_tab() == 3, "E로 다음 탭(수집 기록)으로 넘어간다")
	_press_key(KEY_E)
	await _input_frames()
	_check(_journal.get_tab() == 0, "E로 처음 탭(목표·확인)으로 돌아간다")
	_press_key(KEY_Q)
	await _input_frames()
	_check(_journal.get_tab() == 3, "Q로 이전 탭으로 돌아간다")
	_press_key(KEY_3)
	await _input_frames()
	_check(_journal.get_tab() == 2, "숫자 3은 협회 보고서 탭이다")
	_press_key(KEY_1)
	await _input_frames()
	var goals: Control = _journal.get("_goals_view")
	_check(_journal.get_tab() == 0 and goals.visible, "숫자 1은 목표·확인 탭이다")
	(_journal.get("_tab_buttons")[1] as Button).pressed.emit()
	await _input_frames()
	_check(_journal.get_tab() == 1, "탭 버튼을 눌러도 전환된다")

	# --- 수칙서 렌더링 ---
	_check(_journal.select_document("school_rulebook") and _journal.get_page_text().contains("1."), "무진고 안전수칙서 첫 쪽이 번호 붙은 규칙으로 그려진다")
	var title_label: Label = _journal.get("_doc_title")
	var page_label: Label = _journal.get("_page_title")
	_check(title_label.text == "무진고등학교 안전수칙서" and page_label.text.contains("공통 수칙"), "문서 제목과 구역 제목이 따로 보인다")
	var page0: String = _journal.get_page_text()
	_check(page0.contains("학생 여러분께 안내드립니다") and page0.contains("교내 방송보다 우선합니다") and page0.contains("세 번째 문장이 끝날 때까지"), "서문과 공통 수칙 원문이 실린다")
	_check(page0.contains("공통 수칙"), "서문 쪽에 구역 소제목이 달린다")
	_check(not page0.contains("확인됨"), "협회가 미리 알려 준 규칙은 '확인됨'으로 보이지 않는다")
	_check(page0.contains("협회 기록"), "협회가 미리 알려 준 규칙은 '협회 기록'으로 보인다")
	_check(_rm.status_text("RULE_COMMON_01") == "협회 기록" and not _rm.is_verified("RULE_COMMON_01"), "RuleManager도 협회 기록을 검증 전으로 본다")
	for r in _rm.get_all_rules():
		if r["discovered"] and r.get("source", "") == "association":
			_check(int(r["status"]) != 1, "협회 기록 규칙 %s 는 CONFIRMED 가 아니다" % r["id"])
	_journal.turn_page(1)
	await _input_frames()
	var page1: String = _journal.get_page_text()
	_check(page1.contains("급식 메뉴가 전날과 완전히 같다면") and page1.contains("식판을 받지 마십시오"), "급식실 쪽에는 규칙 원문이 모두 실린다 (아직 모르는 규칙 포함)")
	_check(_count(page1, "위반 결과") == 1, "상태 표시는 알게 된 규칙에만 붙는다 (%d개)" % _count(page1, "위반 결과"))
	_check(page1.contains("— 사비") and (_journal.get("_notes_column") as Control).visible, "알게 된 규칙의 사비 메모는 여백에 사비 필체로 남는다")
	_check(page1.contains("NanumPenScript"), "사비 메모는 사비의 손글씨 글꼴이다")
	_check(not page1.contains(" 확정 "), "직접 확인하지 않은 규칙은 확정이 아니다")
	_journal.set_print_handwriting(true)
	_check(not _journal.get_page_text().contains("NanumPenScript"), "정자체 보기를 켜면 필기를 읽기 쉬운 글꼴로 보여 준다")
	_journal.set_print_handwriting(false)
	_rm.update_rule_status("RULE_CAFETERIA_01", 1)
	await _input_frames()
	_check(_journal.get_page_text().contains(" 확정 ") and _journal.get_page_text().contains(" 정상 ") and _rm.is_verified("RULE_CAFETERIA_01"), "플레이어가 확인한 규칙은 '확정 · 정상'으로 바뀐다")
	_journal.turn_page(-1)
	_journal.turn_page(-1)
	_check(_journal.get_current_page_index() == 0, "첫 쪽에서 더 이전으로 가지 않는다")
	_press_key(KEY_RIGHT)
	await _input_frames()
	_check(_journal.get_current_page_index() == 1, "→ 키로 다음 쪽을 넘긴다")

	# --- 지하철 이동 수칙 ---
	_press_key(KEY_UP)
	await _input_frames()
	_check(_journal.get_current_document_id() == "subway_rules" and _journal.get_page_text().contains("전광판의 열차 번호"), "↑ 로 지하철 이동 수칙을 펼치면 확인 절차가 보인다")

	# --- 보고서 렌더링 ---
	_journal.show_tab(2)
	_journal.select_document("school_report")
	_check(_journal.get_page_text().contains("현장 목적"), "학교 보고서 첫 쪽에 운용 안내가 보인다")
	_check(_journal.get_page_text().contains("— 기록관리팀 / 백서린"), "보고서의 대원 필기는 여백에 서명과 함께 남는다")

	# --- 인벤토리 ---
	_journal.show_tab(3)
	await _input_frames()
	var box: VBoxContainer = _journal.get("_inventory_box")
	_check(box.get_node_or_null("EmptyInventory") != null, "소지품이 없으면 빈 상태 문구가 보인다")
	_inv.add_item("구급상자")
	await _input_frames()
	var row = box.get_node_or_null("Item_구급상자")
	_check(row != null and box.get_node_or_null("EmptyInventory") == null, "인벤토리 탭에 추가한 아이템이 보인다")
	_check(row != null and _has_label_containing(row, "체력을 크게 회복"), "아이템 설명이 함께 보인다")
	_inv.remove_item("구급상자")

	# --- R 별칭 ---
	_journal.close()
	await _input_frames()
	_press("notebook")
	await _input_frames()
	_check(_journal.is_open() and _journal.get_tab() == 1, "R은 수칙서 탭을 바로 연다")
	_press_key(KEY_ESCAPE)
	await _input_frames()
	_check(not _journal.is_open() and not _gm.is_exploration_locked(), "Esc로 닫으면 잠금이 풀린다")

	# --- 대화 중에는 열리지 않는다 ---
	var dm: Node = root.get_node("/root/DialogueManager")
	dm.is_dialogue_active = true
	_press("journal")
	await _input_frames()
	_check(not _journal.is_open(), "대화 중에는 열리지 않는다")
	dm.is_dialogue_active = false

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _ids(docs: Array) -> Array:
	var ids: Array = []
	for d in docs:
		ids.append(String(d["id"]))
	return ids


func _count(text: String, needle: String) -> int:
	return text.count(needle)


func _has_label_containing(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if String((label as Label).text).contains(text):
			return true
	return false


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


## 실제 키 입력 (같은 키에 묶인 액션이 모두 반응한다)
func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


## 입력 이벤트는 process 프레임에 처리되므로 process 프레임을 기다린다
func _input_frames(count: int = 2) -> void:
	for i in count:
		await process_frame


## 학교 챕터를 이야기 없이(run_story=false) 연다
func _open_chapter() -> void:
	var old := current_scene
	var scene: Node = (load(CHAPTER) as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	if old:
		old.queue_free()
