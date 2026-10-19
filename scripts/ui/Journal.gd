extends CanvasLayer

# 프로젝트 벨카 - 조사 기록 수첩 (Tab) — 피그마 시안의 조사 기록 창을 그대로 옮김 (App.tsx JournalOverlay · HandNotes,
# index.css journal-* / paper / hand-note / doc-* / goal-* / card-grid, 끝의 통합 테마 덮어쓰기 포함).
# 1920x1080 기준 좌표·글꼴 크기는 시안을 크롬으로 그려서 잰 값이다.
#   창     : 가운데 1088x736 (416,172) — 장비 케이스(#12171b→#0c1013, 모서리 6, 윗선 #3a454c), 뒤는 흐린 먹색 막
#   머리   : 작은 머리말(나눔고딕코딩 청록) + "조사 기록"(나눔명조), 탭 4개(번호 · 이름 · 수집 수), 닫기 ×
#   목표·확인 : 진행 기록(지금 목표 ▶ 금빛 상자 / 지난 목표 ✓ 청록), 확인한 사실 칩 + 안내 문장
#   맵 규칙서 : 왼쪽 쪽 목록 + 바랜 종이 한 장에 모든 쪽을 이어 쓴다. 구역 제목 · 번호 붙은 조항 · 상태 칩
#               (진행 미확인/협회 기록/추정/확정 · 진위 정상/조건부/오염 · 위반 N), 조항 바로 아래 손글씨 필기
#   협회 보고서 : 왼쪽 쪽 목록(날짜 + 제목, 입수 전 쪽은 '미발견') + 종이 한 쪽 (문서 번호 · 내부 열람 도장 · 본문 ·
#               협회 메모 · 필기 원문)
#   수집 기록 : 입수한 자료 카드 + 미발견 카드(점선) + 소지품 카드
#   아래 띠 : Q E 탭 이동 · 1–4 바로 가기 · Tab 닫기
# 내용은 게임 데이터다: 문서·쪽은 data/journal/documents.json (story flag(unlock_flag)나 규칙 발견(unlock_category /
#   categories)으로 열린다. 새로 열리면 HUD에 알린다), 규칙서 본문은 RuleManager 규칙 데이터, 소지품 설명은
#   data/journal/items.json, 목표는 HUD 의 objective_log.
# 필기: 사비 메모 · 샤무 코멘트 · 보고서의 "> [소속 / 이름] …" 줄은 인물별 손글씨(HANDS, assets/fonts/hand/)로 남고,
#   서명은 "이름 / 소속" 이다. 협회장의 필기는 상자 안에. '정자체 보기'를 켜면 읽기 쉬운 글꼴로 보여 준다.
# 머리말은 평소 "괴이저항단체 / FIELD RECORD / …" 이고, 진상이 드러난 뒤에만 PROJECT VELKA 로 바뀐다
#   (게임_시스템.md 2.29 — 시안의 PROJECT VELKA 표기는 따르지 않는다).
# 시안에 없어서 시안 스타일로 맞춘 것: 문서가 여럿일 때 문서 고르기(목록 머리), 쪽 넘기기(← → · 목록), 문서 넘기기(↑ ↓),
#   새 쪽 표시(●), 위반 결과 등급 칩, 정자체 보기 단추(아래 띠 오른쪽), 손전등 배터리(소지품 머리).
# 열려 있는 동안에는 탐색 입력이 잠긴다. 키: Tab / Esc 닫기, Q E 또는 1~4 탭, ← → (A D) 쪽, ↑ ↓ 문서, 휠 · W S 스크롤.
# 탭을 바꾸면 시안처럼 내용이 살짝 떠오른다 (0.25초). '화면 효과 줄이기'면 끈다.

signal opened()
signal closed()
## 수첩에 새 문서/쪽이 열렸을 때 (page_title이 비어 있으면 문서 전체)
signal page_unlocked(document_id: String, page_title: String)

enum Tab { GOALS, RULEBOOK, REPORT, COLLECTION }

const LOCK_REASON := "journal"
const DOCUMENTS_PATH := "res://data/journal/documents.json"
const ITEMS_PATH := "res://data/journal/items.json"
const TAB_NAMES: Array[String] = ["목표 · 확인", "맵 규칙서", "협회 보고서", "수집 기록"]
const TAB_KINDS: Array[String] = ["", "rulebook", "report", ""]
const NOTICE_COLOR := Color(0.95, 0.85, 0.55)

## 시안 색 (index.css :root · 통합 테마)
const INK := Color("#dcd5c6")
const TEAL := Color("#45a1b5")
const GOLD := Color("#d9a336")
const BLOOD := Color("#8c2630")
const RIG := Color("#0c1013")
const RIG_2 := Color("#12171b")
const RIG_LINE := Color("#263036")
const RIG_HI := Color("#3a454c")
const RIG_INK := Color("#c9d0d3")
const ICON_LINE := Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.4)
const SCREEN_INK := Color("#ece7db")
const PAPER_BG := Color("#e6dfcd")
const PAPER_TEXT := Color("#2a2522")
const PAPER_LEDE := Color("#4a423c")
const CHIP_INK := "#4a423c"
## 창 자리 (시안 .journal: min(68rem, 100%) x min(46rem, 100%), 가운데)
const WINDOW_RECT := Rect2(416, 172, 1088, 736)
const PAGE_IN := 0.25

## 위반 조항 잉크 번짐: 글자 둘레의 번진 잉크 · 글자색 (기록소도 같은 값을 쓴다)
const VIOLATION_BLEED := "#8e2b1f44"
const VIOLATION_TEXT := "#4a1a12"
## 수첩 종이 위의 위반 조항 글자색 (시안 .paper-rule.is-violated p)
const VIOLATION_PAPER_TEXT := "#3a1416"
## 인물별 손글씨 (시안 hand-<인물>): 글꼴 · 잉크 · 크기(px) · 이름 · 소속. 필기 서명의 이름으로 고른다.
## 기록소(RuleArchive)도 font · ink · size · name · dept 를 읽는다 (dept 가 비면 "현장 협력자").
## org 는 수첩 서명용 시안 소속 (사비·샤무: "외부 협력").
const HAND_DIR := "res://assets/fonts/hand/"
const HANDS := {
	"sabi": {"font": HAND_DIR + "Sabi-Hand.ttf", "ink": "#326B7A", "size": 18, "name": "사비 아사기", "dept": "", "org": "외부 협력"},
	"shamu": {"font": HAND_DIR + "Shamu-Hand.ttf", "ink": "#8A592E", "size": 22, "name": "카즈네 샤무", "dept": "", "org": "외부 협력"},
	"kwon": {"font": HAND_DIR + "Kwon-Hand.ttf", "ink": "#4A575D", "size": 18, "name": "권지혁", "dept": "전투대응부"},
	"baek": {"font": HAND_DIR + "Baek-Hand.ttf", "ink": "#6B576D", "size": 21, "name": "백윤서", "dept": "협회장", "boxed": true},
	"seo": {"font": HAND_DIR + "Seo-Hand.ttf", "ink": "#5B6C4F", "size": 19, "name": "서유림", "dept": "보호관리부"},
	"yu": {"font": HAND_DIR + "Yu-Hand.ttf", "ink": "#375C69", "size": 22, "name": "유가온", "dept": "정보조사부"},
	"han": {"font": HAND_DIR + "Han-Hand.ttf", "ink": "#8A6242", "size": 18, "name": "한재윤", "dept": "기술지원부"},
}
const HAND_SABI: Dictionary = HANDS["sabi"]
const HAND_SHAMU: Dictionary = HANDS["shamu"]
## 이름이 정해진 인물이 아닌 협회 대원(기록관리팀 등)의 필기
const HAND_ASSOCIATION := {"font": "res://assets/fonts/Gaegu-Regular.ttf", "ink": "#4f5878", "size": 17, "name": "", "dept": ""}

## 손글씨를 정자체로 보기 (접근성 설정과 같은 값)
static var print_handwriting: bool = false
## 대체 글꼴을 붙인 손글씨 글꼴. 리소스 캐시는 아무도 잡고 있지 않으면 비워지므로 여기서 잡아 둔다.
static var _hand_fonts: Array[Font] = []

var _docs: Array = []
var _item_info: Dictionary = {}
var _tab: int = Tab.REPORT
var _selected_doc: Dictionary = {}   # 탭 -> 선택한 문서 id
var _page_of: Dictionary = {}        # 문서 id -> 열람 가능한 쪽 목록에서의 위치
var _unlocked: Dictionary = {}       # 열려 있는 문서("doc") / 쪽("doc:index") 키
var _unread: Dictionary = {}         # 아직 펼쳐 보지 않은 새 쪽 키
var _pending_notices: Array[String] = []

var _root: Control
var _chapter_label: Label
var _tab_buttons: Array[Button] = []
var _tab_parts: Array[Dictionary] = []
var _hover_tab: int = -1
var _hand_toggle: Button
var _foot_doc_keys: Array[Control] = []
var _body: Control
var _view_tween: Tween
## 목표·확인
var _goals_view: Control
var _goal_list: VBoxContainer
var _fact_chips: HFlowContainer
## 규칙서·보고서
var _docs_view: Control
var _list_box: VBoxContainer
var _doc_scroll: ScrollContainer
var _scroll_thumb: ColorRect
var _sheet_holder: MarginContainer
var _empty_label: Label
var _doc_title: Label
var _page_title: Label
var _section_nodes: Array[Control] = []
var _page_texts: Array[String] = []
## 수집 기록
var _inventory_view: ScrollContainer
var _inventory_box: VBoxContainer


func _ready() -> void:
	layer = 40
	prepare_hand_fonts()
	_load_data()
	_build()
	_root.visible = false
	_scan_unlocks(true)
	GameManager.story_flag_set.connect(_on_flag_set)
	RuleManager.rule_discovered.connect(_on_rule_changed)
	RuleManager.rule_updated.connect(_on_rule_status_changed)
	RuleManager.memo_unlocked.connect(_on_memo_unlocked)
	RuleManager.rules_loaded.connect(_on_rules_loaded)
	InventoryManager.item_added.connect(_on_item_changed)
	InventoryManager.item_removed.connect(_on_item_changed)
	DialogueManager.dialogue_completed.connect(_on_dialogue_completed)


func _exit_tree() -> void:
	# 열린 채로 장면이 바뀌어도 잠금이 남지 않게 한다
	GameManager.set_exploration_lock(LOCK_REASON, false)


# --- 열기 / 닫기 ------------------------------------------------------------

func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## 수첩을 연다. tab이 -1이면 새 쪽이 있는 탭, 없으면 마지막으로 본 탭. 대화·실패·다른 잠금 중에는 열리지 않는다.
## 이미 열려 있으면 tab 으로 넘긴다.
func open(tab: int = -1) -> void:
	if is_open():
		if tab >= 0:
			show_tab(tab)
		return
	if not can_open():
		return
	_tab = tab if tab >= 0 and tab < TAB_NAMES.size() else _default_tab()
	_scan_unlocks(true)
	_render()
	_root.visible = true
	_play_page_in()
	GameManager.set_exploration_lock(LOCK_REASON, true)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	GameManager.set_exploration_lock(LOCK_REASON, false)
	closed.emit()


## 지금 열 수 있는 상황인가 (대화, 실패 화면, 컷신·미니게임 같은 다른 탐색 잠금, 일시정지 중에는 안 된다)
func can_open() -> bool:
	if get_tree().paused or FailureManager.is_failing:
		return false
	return not GameManager.is_exploration_locked()


func _input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed("journal"):
			open()
		elif event.is_action_pressed("notebook"):
			open(Tab.RULEBOOK)
		else:
			return
		if is_open():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		if _tab == Tab.RULEBOOK:
			close()
		else:
			show_tab(Tab.RULEBOOK)
	elif event is InputEventKey and event.pressed:
		if _handle_key(event):
			get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> bool:
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_W or code == KEY_S or code == KEY_PAGEUP or code == KEY_PAGEDOWN:
		var step := 56.0 if code == KEY_W or code == KEY_S else 420.0
		_scroll_body(-step if code == KEY_W or code == KEY_PAGEUP else step)
		return true
	if event.echo:
		return false
	match code:
		KEY_Q:
			show_tab(posmod(_tab - 1, TAB_NAMES.size()))
		KEY_E:
			show_tab(posmod(_tab + 1, TAB_NAMES.size()))
		KEY_1, KEY_2, KEY_3, KEY_4:
			show_tab(int(code) - int(KEY_1))
		KEY_LEFT, KEY_A:
			turn_page(-1)
		KEY_RIGHT, KEY_D:
			turn_page(1)
		KEY_UP:
			step_document(-1)
		KEY_DOWN:
			step_document(1)
		_:
			return false
	return true


# --- 외부에서 쓰는 조회 · 조작 ------------------------------------------------

func get_tab() -> int:
	return _tab


## 지금 펼친 문서 id (없으면 빈 문자열)
func get_current_document_id() -> String:
	return String(_selected_doc.get(_tab, ""))


## 지금 보이는 쪽 번호 (0부터, 열람 가능한 쪽 기준)
func get_current_page_index() -> int:
	return int(_page_of.get(get_current_document_id(), 0))


## 열람 가능한 문서 목록 (kind: report / rulebook)
func get_documents(kind: String) -> Array:
	var result: Array = []
	for doc in _docs:
		if String(doc.get("kind", "")) == kind and _unlocked.has(String(doc["id"])):
			result.append(doc)
	return result


func is_document_unlocked(document_id: String) -> bool:
	return _unlocked.has(document_id)


## 문서에서 열람 가능한 쪽 목록
func get_pages(document_id: String) -> Array:
	var doc := _doc_by_id(document_id)
	var result: Array = []
	if doc.is_empty():
		return result
	var pages: Array = doc.get("pages", [])
	for i in pages.size():
		if _unlocked.has(_page_key(document_id, i)):
			result.append(pages[i])
	return result


func show_tab(tab: int) -> void:
	if tab < 0 or tab >= TAB_NAMES.size() or tab == _tab:
		return
	_tab = tab
	_render()
	_play_page_in()


## 문서를 펼친다. 문서가 없거나 아직 입수하지 않았으면 false
func select_document(document_id: String) -> bool:
	var doc := _doc_by_id(document_id)
	if doc.is_empty() or not _unlocked.has(document_id):
		return false
	var tab := TAB_KINDS.find(String(doc.get("kind", "")))
	if tab < 0:
		return false
	var changed_tab := tab != _tab
	_tab = tab
	_selected_doc[tab] = document_id
	_render()
	if changed_tab:
		_play_page_in()
	return true


func step_document(delta: int) -> void:
	if TAB_KINDS[_tab].is_empty():
		return
	var docs := get_documents(TAB_KINDS[_tab])
	if docs.size() < 2:
		return
	var at := 0
	for i in docs.size():
		if String(docs[i]["id"]) == get_current_document_id():
			at = i
	_selected_doc[_tab] = String(docs[clampi(at + delta, 0, docs.size() - 1)]["id"])
	_render()


func turn_page(delta: int) -> void:
	if TAB_KINDS[_tab].is_empty():
		return
	var id := get_current_document_id()
	if id.is_empty():
		return
	_show_page(id, int(_page_of.get(id, 0)) + delta)


## 문서의 쪽(열람 가능한 쪽 기준 번호)을 펼친다. 규칙서는 이어 쓴 종이에서 그 구역으로 스크롤한다.
func _show_page(document_id: String, index: int) -> void:
	var count := get_pages(document_id).size()
	_page_of[document_id] = clampi(index, 0, maxi(count - 1, 0))
	_render()


## 지금 쪽의 BBCode (본문 + 필기, 테스트·점검용)
func get_page_text() -> String:
	var index := get_current_page_index()
	if index < 0 or index >= _page_texts.size():
		return ""
	return _page_texts[index]


## 손글씨 부분 글꼴에 없는 기호(화살표·괄호 등)는 Pretendard 로 보이게 한다. 글꼴 리소스는 캐시되므로
## BBCode [font=경로] 로 불러도 같은 리소스(같은 대체 글꼴)를 쓴다.
static func prepare_hand_fonts() -> void:
	var paths: Array = [HAND_ASSOCIATION["font"]]
	for hand in HANDS.values():
		paths.append(hand["font"])
	for path in paths:
		var f := load(String(path)) as Font
		if f == null:
			continue
		if f.fallbacks.is_empty():
			f.fallbacks = [VelkaStyle.sans()]
		if not _hand_fonts.has(f):
			_hand_fonts.append(f)


## 필기 서명 "소속 / 이름" 에서 인물의 손글씨를 고른다 (이름이 정해진 인물이 아니면 협회 공용 필체)
static func hand_for_signer(signer: String) -> Dictionary:
	for hand in HANDS.values():
		if signer.contains(String(hand["name"])):
			return hand
	return HAND_ASSOCIATION


## "소속 / 이름" → "이름 / 소속" (시안 서명 표기)
static func signature(signer: String) -> String:
	var parts := signer.split("/", false)
	if parts.size() == 2:
		return "%s / %s" % [parts[1].strip_edges(), parts[0].strip_edges()]
	return signer.strip_edges()


## 손글씨 ↔ 정자체
func set_print_handwriting(on: bool) -> void:
	print_handwriting = on
	if is_open():
		_render()


## 현재 상태로 다시 그린다
func refresh() -> void:
	_render()


# --- 데이터 · 열림 판정 --------------------------------------------------------

func _load_data() -> void:
	var docs = _read_json(DOCUMENTS_PATH)
	if docs is Dictionary:
		_docs = docs.get("documents", [])
	var items = _read_json(ITEMS_PATH)
	if items is Dictionary:
		_item_info = items.get("items", {})


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[Journal] 파일이 없습니다: %s" % path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _doc_by_id(document_id: String) -> Dictionary:
	for doc in _docs:
		if String(doc.get("id", "")) == document_id:
			return doc
	return {}


func _page_key(document_id: String, index: int) -> String:
	return "%s:%d" % [document_id, index]


func _flag_ok(flag_name: String) -> bool:
	return flag_name.is_empty() or bool(GameManager.get_story_flag(flag_name, false))


## 쪽이 열려 있나: 문서 flag + 쪽 flag + (규칙 구역을 하나라도 알게 됐는가)
func _page_open(doc: Dictionary, page: Dictionary) -> bool:
	if not _flag_ok(String(doc.get("unlock_flag", ""))) or not _flag_ok(String(page.get("unlock_flag", ""))):
		return false
	var cats: Array = page.get("categories", []).duplicate()
	if page.has("unlock_category"):
		cats.append(String(page["unlock_category"]))
	if cats.is_empty():
		return true
	for cat in cats:
		if not RuleManager.get_rules_by_category(String(cat), true).is_empty():
			return true
	return false


## 열린 문서·쪽을 다시 계산한다. silent가 아니면 새로 열린 것을 HUD에 알리고 '새 쪽' 표시를 남긴다.
func _scan_unlocks(silent: bool) -> void:
	var current: Dictionary = {}
	var fresh_docs: Array = []
	var fresh_pages: Array = []
	for doc in _docs:
		var id := String(doc.get("id", ""))
		var pages: Array = doc.get("pages", [])
		var any_open := false
		for i in pages.size():
			if _page_open(doc, pages[i]):
				any_open = true
				var key := _page_key(id, i)
				current[key] = true
				if not _unlocked.has(key):
					fresh_pages.append([doc, pages[i], key])
		if any_open:
			current[id] = true
			if not _unlocked.has(id):
				fresh_docs.append(doc)
	var old := _unlocked
	_unlocked = current
	for key in _unread.keys():
		if not current.has(key):
			_unread.erase(key)
	if silent:
		return
	for entry in fresh_pages:
		_unread[entry[2]] = true
	for doc in fresh_docs:
		_announce("수첩에 새 문서: %s" % String(doc["title"]), String(doc["id"]), "")
	for entry in fresh_pages:
		var doc: Dictionary = entry[0]
		if old.has(String(doc["id"])):
			_announce("수첩에 새 페이지: %s — %s" % [String(doc["title"]), String(entry[1].get("title", ""))],
					String(doc["id"]), String(entry[1].get("title", "")))


func _announce(text: String, document_id: String, page_title: String) -> void:
	page_unlocked.emit(document_id, page_title)
	_pending_notices.append(text)
	_flush_notices.call_deferred()


## 대화나 실패 화면이 끝난 뒤에 HUD 알림을 띄운다
func _flush_notices() -> void:
	if _pending_notices.is_empty() or not is_inside_tree():
		return
	if DialogueManager.is_dialogue_active or FailureManager.is_failing:
		return
	for text in _pending_notices:
		get_tree().call_group("rule_warning_listener", "show_notice", text, NOTICE_COLOR, 3.5)
	_pending_notices.clear()


func _on_flag_set(_flag_name: String, _value: Variant) -> void:
	_on_data_changed()


func _on_rule_changed(_rule_id: String) -> void:
	_on_data_changed()


func _on_rule_status_changed(_rule_id: String, _status: int) -> void:
	_on_data_changed()


func _on_memo_unlocked(_rule_id: String, _character: String) -> void:
	_on_data_changed()


func _on_rules_loaded(_total: int) -> void:
	_scan_unlocks(true)


func _on_item_changed(_item_name) -> void:
	_on_data_changed()


func _on_dialogue_completed(_dialogue_id: String) -> void:
	_flush_notices()


func _on_data_changed() -> void:
	_scan_unlocks(false)
	if is_open():
		_render()


func _default_tab() -> int:
	for tab in [Tab.REPORT, Tab.RULEBOOK]:
		if _tab_has_unread(tab):
			return tab
	return _tab


func _tab_has_unread(tab: int) -> bool:
	if TAB_KINDS[tab].is_empty():
		return false
	for doc in get_documents(TAB_KINDS[tab]):
		if _doc_has_unread(String(doc["id"])):
			return true
	return false


func _doc_has_unread(document_id: String) -> bool:
	for key in _unread:
		if String(key).begins_with(document_id + ":"):
			return true
	return false


func _objective_log() -> Array:
	var hud := get_tree().get_first_node_in_group("rule_warning_listener")
	if hud and "objective_log" in hud:
		return hud.objective_log
	return []


func _reduce_effects() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.has_method("reduce_effects") and bool(settings.reduce_effects())


# --- 그리기 -----------------------------------------------------------------

func _render() -> void:
	_render_header()
	_render_tabs()
	var is_docs := not TAB_KINDS[_tab].is_empty()
	_hand_toggle.text = "손글씨 보기" if print_handwriting else "정자체 보기"
	_hand_toggle.visible = is_docs
	for c in _foot_doc_keys:
		c.visible = is_docs
	_goals_view.visible = _tab == Tab.GOALS
	_inventory_view.visible = _tab == Tab.COLLECTION
	_docs_view.visible = is_docs
	match _tab:
		Tab.GOALS:
			_render_goals()
			return
		Tab.COLLECTION:
			_render_inventory()
			return
	var docs := get_documents(TAB_KINDS[_tab])
	if docs.is_empty():
		_clear(_list_box)
		_clear(_sheet_holder)
		_page_texts.clear()
		_section_nodes.clear()
		_doc_scroll.visible = false
		_empty_label.visible = true
		_empty_label.text = "아직 받은 보고서가 없다." if _tab == Tab.REPORT else "아직 입수한 수칙서가 없다.\n가는 곳마다 안내문이 붙어 있을지도 모른다."
		return
	_empty_label.visible = false
	_doc_scroll.visible = true
	var selected := String(_selected_doc.get(_tab, ""))
	var doc := _doc_by_id(selected)
	if doc.is_empty() or not _unlocked.has(selected):
		doc = docs[0]
		_selected_doc[_tab] = String(doc["id"])
	var id := String(doc["id"])
	var pages := get_pages(id)
	_page_of[id] = clampi(int(_page_of.get(id, 0)), 0, maxi(pages.size() - 1, 0))
	if _tab == Tab.RULEBOOK:
		_build_rulebook_paper(doc)
	else:
		_build_report_paper(doc)
	_rebuild_list(docs)
	_render_tabs()
	_focus_page.call_deferred()


## 머리말: 괴이저항단체 / FIELD RECORD / CHAPTER
## (프로젝트 벨카의 진상이 드러나면 — VelkaStyle.VELKA_REVEAL_FLAG — 기록의 머리가 조용히 PROJECT VELKA 로 바뀐다)
func _render_header() -> void:
	var scene := get_tree().current_scene
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	_chapter_label.text = ("PROJECT VELKA" if VelkaStyle.velka_revealed() else "괴이저항단체") + " / FIELD RECORD / " + ("PROLOGUE" if chapter.begins_with("Prologue") else "CHAPTER 01" if chapter.begins_with("Chapter1") else "FIELD")


## 탭: 번호(작은 고딕코딩) · 이름 · (수집 기록만) 개수 상자. 고른 탭은 밝은 글자 + 아래 2px 선
func _render_tabs() -> void:
	for i in _tab_buttons.size():
		var parts: Dictionary = _tab_parts[i]
		var active := i == _tab
		var lit := active or i == _hover_tab
		var ink := INK if lit else Color(INK, 0.5)
		(parts["num"] as Label).add_theme_color_override("font_color", Color(ink, ink.a * 0.6))
		(parts["name"] as Label).add_theme_color_override("font_color", ink)
		var em_label := parts["em_label"] as Label
		em_label.add_theme_color_override("font_color", ink)
		var em_style := (parts["em"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		em_style.border_color = ink
		parts["em_wrap"].visible = i == Tab.COLLECTION
		if i == Tab.COLLECTION:
			em_label.text = str(_collection_count())
		parts["dot"].visible = _tab_has_unread(i)
		var style := _tab_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
		style.border_color = RIG_INK if active else Color(0, 0, 0, 0)


func _collection_count() -> int:
	return get_documents("rulebook").size() + get_documents("report").size() + InventoryManager.items.size()


# --- 왼쪽 목록 (시안 .doc-index) ------------------------------------------------

## 문서가 하나면 머리글(수칙서 · N쪽 / MJ-01 · 입수본) 아래에 쪽 목록. 여럿이면 고른 문서만 펼치고 나머지는 문서 줄로.
func _rebuild_list(docs: Array) -> void:
	_clear(_list_box)
	var selected := get_current_document_id()
	for doc in docs:
		var id := String(doc["id"])
		var code := _doc_code(doc)
		if id != selected:
			var entry := _index_entry("Doc_" + id, code, String(doc["title"]), false, false, _doc_has_unread(id))
			entry.get_meta("button").pressed.connect(select_document.bind(id))
			_list_box.add_child(entry)
			continue
		var head := _text(code, VelkaStyle.spaced(VelkaStyle.mono(), 1), 11, Color(INK, 0.45))
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_box.add_child(_margin(head, 0, 0, 0, 6))
		var pages: Array = doc.get("pages", [])
		var open_index := 0
		var current := get_current_page_index()
		for i in pages.size():
			var page: Dictionary = pages[i]
			if not _unlocked.has(_page_key(id, i)):
				# 보고서는 입수 전 쪽을 '미발견'으로 남긴다. 규칙서 목록은 시안처럼 종이에 있는 구역만 보인다.
				if _tab == Tab.REPORT:
					_list_box.add_child(_index_entry("Locked_%d" % i, "미발견", "—", false, true, false))
				continue
			var at := open_index
			var small := ""
			var title := String(page.get("title", ""))
			if _tab == Tab.REPORT:
				var head_info := _report_heading(doc, page)
				small = head_info[0]
				title = head_info[2]
			var entry := _index_entry("Page_%d" % i, small, title, at == current, false, _unread.has(_page_key(id, i)))
			entry.get_meta("button").pressed.connect(_show_page.bind(id, at))
			_list_box.add_child(entry)
			open_index += 1


## 목록 머리글: 수칙서 · N쪽 / MJ-NN · 입수본
func _doc_code(doc: Dictionary) -> String:
	if String(doc.get("kind", "")) == "rulebook":
		return "수칙서 · %d쪽" % get_pages(String(doc["id"])).size()
	return "MJ-%02d · 입수본" % (_docs.find(doc) + 1)


## 목록 한 줄 (시안 .doc-index a / button): 작은 머리(날짜) + 제목, 왼쪽 2px 핏빛 선은 고른 줄·마우스 오버.
## 입수 전 쪽은 흐리게(35%) + 왼쪽 점선.
func _index_entry(node_name: String, small: String, title: String, active: bool, locked: bool, unread: bool) -> Control:
	var holder := PanelContainer.new()
	holder.name = node_name
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var b := Button.new()
	b.name = "Button"
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = locked
	if locked:
		var dashed := DashedStyle.new()
		dashed.color = Color(INK, 0.3)
		dashed.sides = [false, false, false, true]
		for state in ["normal", "disabled", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, dashed)
		holder.modulate.a = 0.35
	else:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(INK, 0.04) if active else Color(0, 0, 0, 0)
		normal.border_color = BLOOD if active else Color(0, 0, 0, 0)
		normal.border_width_left = 2
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(INK, 0.04)
		hover.border_color = BLOOD
		for state in ["normal", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, normal)
		for state in ["hover", "pressed"]:
			b.add_theme_stylebox_override(state, hover)
	holder.add_child(b)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var ink := INK if active else Color(INK, 0.65)
	var small_label: Label = null
	if not small.is_empty():
		small_label = _text(small, VelkaStyle.mono(), 10, Color(ink, ink.a * 0.7))
		small_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(small_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title_label := _text(title, VelkaStyle.sans(), 13, ink)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	if unread:
		var dot := _text("●", VelkaStyle.sans(), 8, TEAL)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
	column.add_child(row)
	# 시안 padding 0.5rem: Godot 글줄이 크롬보다 1~2px 높아서 위아래를 그만큼 줄인다 (줄 높이 31 / 42.6 에 맞춤)
	var pad := 6.0 if small_label else 7.0
	holder.add_child(_margin(column, 11.6, pad, 9.6, pad))
	_ignore_mouse(column)
	if not locked and not active:
		b.mouse_entered.connect(func():
			title_label.add_theme_color_override("font_color", INK)
			if small_label:
				small_label.add_theme_color_override("font_color", Color(INK, 0.7)))
		b.mouse_exited.connect(func():
			title_label.add_theme_color_override("font_color", ink)
			if small_label:
				small_label.add_theme_color_override("font_color", Color(ink, ink.a * 0.7)))
	holder.set_meta("button", b)
	return holder


# --- 맵 규칙서 종이 (시안 .paper.rulebook-paper) ------------------------------------

## 문서 제목(h2) + 서문(paper-lede) + '여백에 남은 필기' + 열람 가능한 모든 쪽을 한 장에 이어 쓴다.
func _build_rulebook_paper(doc: Dictionary) -> void:
	var id := String(doc["id"])
	var sheet := _new_sheet()
	_page_texts.clear()
	_section_nodes.clear()
	_doc_title = _text(String(doc["title"]), VelkaStyle.serif(), 22, PAPER_TEXT)
	_doc_title.name = "DocTitle"
	_doc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_margin(_doc_title, 0, 0, 0, 9.6))
	_page_title = null
	var pages := get_pages(id)
	var current := get_current_page_index()
	var labeled := false
	for i in pages.size():
		var page: Dictionary = pages[i]
		var section := VBoxContainer.new()
		section.name = "Section_%d" % i
		section.add_theme_constant_override("separation", 0)
		sheet.add_child(section)
		_section_nodes.append(section)
		var text := ""
		var first_h3: Label = null
		var blocks: Array = []
		for line in page.get("intro", []):
			blocks.append({"t": "lede", "text": String(line)})
		var tail: Array = []
		for line in page.get("outro", []):
			tail.append({"t": "lede", "text": String(line)})
		for block in blocks:
			text += String(block["text"]) + "\n"
			section.add_child(_block_node(block, true))
		if doc.has("ruleset"):
			var notes: Array = []
			text += _rules_bbcode(page, notes)
			var cats: Array = page.get("categories", [])
			var unnumbered: Array = page.get("unnumbered", [])
			for cat in cats:
				var rules: Array = RuleManager.get_rules_by_category(String(cat), false)
				if rules.is_empty():
					continue
				rules.sort_custom(func(a, b): return int(a["number"]) < int(b["number"]))
				var plain: bool = unnumbered.has(cat)
				if not plain:
					if not labeled:
						section.add_child(_margin_label("여백에 남은 필기"))
						labeled = true
					var h3 := _h3(String(rules[0].get("category_name", page.get("title", cat))), true)
					section.add_child(h3)
					if first_h3 == null:
						first_h3 = h3.get_meta("label")
				for r in rules:
					section.add_child(_rule_node(r, plain))
			text += _notes_text(notes)
		else:
			if not labeled:
				section.add_child(_margin_label("여백에 남은 필기"))
				labeled = true
			var h3 := _h3(String(page.get("title", "")), true)
			section.add_child(h3)
			first_h3 = h3.get_meta("label")
			text += String(page.get("title", "")) + "\n"
			var notes: Array = []
			var line_blocks := _line_blocks(page.get("lines", []), notes)
			for block in line_blocks:
				section.add_child(_block_node(block, true))
			text += _blocks_text(line_blocks)
			if not notes.is_empty():
				section.add_child(_notes_node(notes, 32))
				text += _notes_text(notes)
		for block in tail:
			text += String(block["text"]) + "\n"
			section.add_child(_block_node(block, true))
		_page_texts.append(text)
		if i == current:
			_page_title = first_h3
		# 이어 쓴 종이는 모든 쪽이 보이므로 '새 쪽' 표시를 지운다
	for i in (doc.get("pages", []) as Array).size():
		_unread.erase(_page_key(id, i))
	if _page_title == null:
		_page_title = _doc_title


## 규칙서 BBCode(점검·테스트용 글): 구역 제목 + 번호 붙은 조항 + 상태 칩(알게 된 규칙만). 필기는 notes 에 모은다.
## 위반한 조항은 잉크가 번진다 (시안 .paper-rule.is-violated — 화면도 같은 BBCode 로 그린다).
func _rules_bbcode(page: Dictionary, notes: Array) -> String:
	var out := ""
	var cats: Array = page.get("categories", [])
	var unnumbered: Array = page.get("unnumbered", [])
	for cat in cats:
		var rules: Array = RuleManager.get_rules_by_category(String(cat), false)
		if rules.is_empty():
			continue
		rules.sort_custom(func(a, b): return int(a["number"]) < int(b["number"]))
		if not unnumbered.has(cat):
			out += "%s\n" % _esc(String(rules[0].get("category_name", cat)))
		for r in rules:
			var prefix := "" if unnumbered.has(cat) else "%d.  " % int(r["number"])
			out += prefix + _rule_text_bbcode(r) + "\n"
			if bool(r.get("discovered", false)):
				for chip in _rule_chips(r):
					out += " %s " % String(chip[0])
				out += "\n"
				notes.append_array(_rule_memos(r))
	return out


func _rule_text_bbcode(r: Dictionary) -> String:
	var text := _esc(String(r["text"]))
	if int(r.get("strikes", 0)) > 0:
		text = "[outline_size=%d][outline_color=%s][color=%s]%s[/color][/outline_color][/outline_size]" % [
				mini(2 + int(r["strikes"]), 5), VIOLATION_BLEED, VIOLATION_PAPER_TEXT, text]
	return text


## 상태 칩 [글, 종류]: 진행(미확인 · 협회 기록 · 추정 · 확정) · 진위(확정 뒤에만: 정상 / 조건부 / 오염) · 위반 N.
## 시안에 없는 위반 결과 등급 칩은 기본 칩 모양으로 뒤에 붙인다.
func _rule_chips(r: Dictionary) -> Array:
	var id := String(r["id"])
	var status := int(r.get("status", 0))
	var progress := "미확인"
	var veracity := ""
	match status:
		RuleManager.RuleStatus.GUESSED:
			progress = "추정"
		RuleManager.RuleStatus.CONFIRMED:
			progress = "확정"
			veracity = "정상"
		RuleManager.RuleStatus.ANOMALY:
			progress = "확정"
			veracity = "오염"
		RuleManager.RuleStatus.ERROR:
			progress = "확정"
			veracity = "조건부"
	if RuleManager.status_text(id) == RuleManager.ASSOCIATION_TEXT:
		progress = RuleManager.ASSOCIATION_TEXT
	var chips: Array = [[progress, "stage-" + progress]]
	if not veracity.is_empty():
		chips.append([veracity, "truth-" + veracity])
	if int(r.get("strikes", 0)) > 0:
		chips.append(["위반 %d" % int(r["strikes"]), "violated"])
	var grade := RuleManager.grade_info(RuleManager.grade_of(id))
	chips.append(["위반 결과 · " + String(grade.get("name", "?")), "grade"])
	return chips


## 알게 된 규칙에 열린 사비 메모 · 샤무 코멘트 (조항 바로 아래 필기)
func _rule_memos(r: Dictionary) -> Array:
	var notes: Array = []
	if r.get("memo_unlocked_sabi", false) and not String(r.get("sabi_memo", "")).is_empty():
		notes.append({"hand": HAND_SABI, "text": String(r["sabi_memo"]), "sign": "%s / %s" % [HAND_SABI["name"], HAND_SABI["org"]]})
	if r.get("memo_unlocked_shamu", false) and not String(r.get("shamu_comment", "")).is_empty():
		notes.append({"hand": HAND_SHAMU, "text": String(r["shamu_comment"]), "sign": "%s / %s" % [HAND_SHAMU["name"], HAND_SHAMU["org"]]})
	return notes


## 조항 한 줄 (시안 .paper-rule): 번호 · 본문 · 칩, 아래 필기, 아래 점선. 서문처럼 번호 없는 조항은 paper-lede 모양.
func _rule_node(r: Dictionary, plain: bool) -> Control:
	var box := PanelContainer.new()
	box.name = "Rule_" + String(r["id"])
	var violated := int(r.get("strikes", 0)) > 0
	if plain:
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		var line := DashedStyle.new()
		line.color = Color(PAPER_TEXT, 0.15)
		line.sides = [false, false, true, false]
		line.content_margin_top = 11.2
		line.content_margin_bottom = 12.2
		box.add_theme_stylebox_override("panel", line)
	if violated:
		box.add_child(InkBlot.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	box.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var size := 14 if plain else 15
	var lh := 23.12 if plain else 25.08
	if not plain:
		# 번호는 본문 첫 줄과 글자 바닥선을 맞춘다 (시안 align-items: baseline)
		var num := _text("%d." % int(r["number"]), VelkaStyle.serif(), 14, Color(PAPER_TEXT, 0.55))
		num.custom_minimum_size.x = 22.4
		var serif := VelkaStyle.serif()
		var drop := maxf((lh - serif.get_height(size)) * 0.5, 0.0) + serif.get_ascent(size) - serif.get_ascent(14)
		var num_wrap := _margin(num, 0, drop, 0, 0)
		num_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(num_wrap)
	var body := _rich(_rule_text_bbcode(r), VelkaStyle.serif(), size, PAPER_LEDE if plain else PAPER_TEXT, lh)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var discovered := bool(r.get("discovered", false))
	if discovered:
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		for chip in _rule_chips(r):
			chips.add_child(_paper_chip(String(chip[0]), String(chip[1])))
		var chips_wrap := _margin(chips, 0, 5.5, 0, 0)
		chips_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(chips_wrap)
		var notes := _rule_memos(r)
		if not notes.is_empty():
			column.add_child(_notes_node(notes, 0 if plain else 32))
	return box


## 종이 위 칩 (시안 .chip): 9.6px Pretendard, 1px 테두리. 협회 기록은 점선, 오염 · 위반은 핏빛 바탕 흰 글자.
func _paper_chip(text: String, kind: String) -> Control:
	var chip := PanelContainer.new()
	var border := Color(PAPER_TEXT, 0.35)
	var ink := Color(CHIP_INK)
	var bg := Color(0, 0, 0, 0)
	match kind:
		"stage-확정":
			border = Color("#326b7a")
			ink = border
		"stage-추정", "truth-조건부":
			border = Color("#8a592e")
			ink = border
		"truth-오염", "violated":
			border = BLOOD
			ink = Color.WHITE
			bg = BLOOD
	var style: StyleBox
	if kind == "stage-" + RuleManager.ASSOCIATION_TEXT:
		var dashed := DashedStyle.new()
		dashed.color = border
		dashed.dash = 2.0
		dashed.gap = 2.0
		style = dashed
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = bg
		flat.border_color = border
		flat.set_border_width_all(1)
		style = flat
	style.content_margin_left = 7.4
	style.content_margin_right = 7.4
	style.content_margin_top = 2.6
	style.content_margin_bottom = 2.6
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_text(text, VelkaStyle.sans(), 10, ink))
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return chip


# --- 협회 보고서 종이 (시안 .paper.report-paper) ----------------------------------

## 문서 번호 + 내부 열람 도장, h2(작은 날짜 + 제목), 본문(report-text) · 협회 메모(report-memo), 필기 원문
func _build_report_paper(doc: Dictionary) -> void:
	var id := String(doc["id"])
	var sheet := _new_sheet()
	_page_texts.clear()
	_section_nodes.clear()
	var pages := get_pages(id)
	var index := get_current_page_index()
	var page: Dictionary = pages[index] if not pages.is_empty() else {}
	var all_pages: Array = doc.get("pages", [])
	for i in all_pages.size():
		if all_pages[i] == page:
			_unread.erase(_page_key(id, i))
	var section := VBoxContainer.new()
	section.name = "Section_0"
	section.add_theme_constant_override("separation", 0)
	sheet.add_child(section)
	# 문서 번호 · 내부 열람 도장
	var docno_row := HBoxContainer.new()
	docno_row.custom_minimum_size.y = 26
	var docno := _text("문서 번호 MJ-%02d-%02d" % [_docs.find(doc) + 1, all_pages.find(page)], VelkaStyle.mono(), 11, Color(PAPER_TEXT, 0.6))
	docno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docno.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	docno_row.add_child(docno)
	var stamp := PanelContainer.new()
	stamp.name = "Stamp"
	var stamp_style := StyleBoxFlat.new()
	stamp_style.bg_color = Color(0, 0, 0, 0)
	stamp_style.border_color = Color(BLOOD, 0.75)
	stamp_style.set_border_width_all(2)
	stamp_style.content_margin_left = 11.6
	stamp_style.content_margin_right = 11.6 - 2.3
	stamp_style.content_margin_top = 6
	stamp_style.content_margin_bottom = 6
	stamp.add_theme_stylebox_override("panel", stamp_style)
	stamp.add_child(_text("내부 열람", VelkaStyle.spaced(VelkaStyle.sans_semibold(), 2), 12, Color(BLOOD, 0.85)))
	var tilt := TiltBox.new()
	tilt.degrees = -5.0
	tilt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tilt.add_child(stamp)
	docno_row.add_child(tilt)
	section.add_child(docno_row)
	# h2: 작은 머리(날짜 또는 문서 이름) + 제목
	var head := _report_heading(doc, page)
	var h2 := VBoxContainer.new()
	h2.add_theme_constant_override("separation", 3)
	_doc_title = _text(head[0], VelkaStyle.mono(), 12, BLOOD)
	_doc_title.name = "DocTitle"
	h2.add_child(_doc_title)
	_page_title = _text(head[1], VelkaStyle.sans_semibold(), 22, PAPER_TEXT)
	_page_title.name = "PageTitle"
	_page_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h2.add_child(_page_title)
	var lines: Array = (page.get("lines", []) as Array).duplicate()
	if not lines.is_empty() and String(lines[0]).begins_with("# ") and String(lines[0]).contains(" — "):
		lines.remove_at(0)
	# h2 아래 여백(0.6rem)은 바로 이어지는 소제목의 위 여백(1.6rem)과 겹친다
	var next_is_h3 := not lines.is_empty() and String(lines[0]).begins_with("# ")
	section.add_child(_margin(h2, 0, 16, 0, 0.0 if next_is_h3 else 9.6))
	var notes: Array = []
	var blocks := _line_blocks(lines, notes)
	for block in blocks:
		section.add_child(_block_node(block, false))
	var text := "%s\n%s\n" % [head[0], head[1]] + _blocks_text(blocks)
	if not notes.is_empty():
		section.add_child(_margin_label("필기 원문 · 작성자 구분"))
		section.add_child(_notes_node(notes, 0))
		text += _notes_text(notes)
	_page_texts.resize(index + 1)
	_page_texts[index] = text
	_section_nodes.append(section)


## 보고서 쪽의 [작은 머리, 종이 제목, 목록 제목]. 첫 소제목이 "날짜 / 차수 — 장소" 이면 날짜와 장소를 쓴다.
func _report_heading(doc: Dictionary, page: Dictionary) -> Array:
	var title := String(page.get("title", ""))
	var lines: Array = page.get("lines", [])
	if not lines.is_empty() and String(lines[0]).begins_with("# ") and String(lines[0]).contains(" — "):
		var parts := String(lines[0]).substr(2).split(" — ", true, 1)
		return [parts[0].strip_edges(), title, parts[1].strip_edges()]
	return [String(doc.get("title", "")), title, title]


# --- 줄 표기 → 종이 블록 ---------------------------------------------------------

## 줄 표기: "# 소제목", "> 인용(사건 기록)", "> [소속 / 이름] 필기"(필기로), "- 항목", "@ 라벨|내용", 빈 줄, 그 외 문단
func _line_blocks(lines: Array, notes: Array) -> Array:
	var blocks: Array = []
	for raw in lines:
		var line := String(raw)
		if line.is_empty():
			continue
		if line.begins_with("# "):
			blocks.append({"t": "h3", "text": line.substr(2)})
		elif line.begins_with("> [") and line.find("]") > 3:
			# 대원이 남긴 필기: "> [3팀장 / 강윤] 내용" -> 필기 원문으로, 각자의 손글씨
			var close := line.find("]")
			var who := line.substr(3, close - 3).strip_edges()
			notes.append({"hand": hand_for_signer(who), "text": line.substr(close + 1).strip_edges(), "sign": signature(who)})
		elif line.begins_with("> "):
			blocks.append({"t": "quote", "text": line.substr(2)})
		elif line.begins_with("- "):
			blocks.append({"t": "item", "text": line.substr(2)})
		elif line.begins_with("@ ") and line.contains("|"):
			var parts := line.substr(2).split("|", true, 1)
			blocks.append({"t": "memo", "label": parts[0], "text": parts[1]})
		else:
			blocks.append({"t": "para", "text": line})
	return blocks


func _blocks_text(blocks: Array) -> String:
	var out := ""
	for block in blocks:
		if block.has("label"):
			out += String(block["label"]) + "  "
		out += _esc(String(block["text"])) + "\n"
	return out


## 블록 하나를 종이 위 노드로. serif = 규칙서(나눔명조), 아니면 보고서(Pretendard)
func _block_node(block: Dictionary, serif: bool) -> Control:
	var regular := VelkaStyle.serif() if serif else VelkaStyle.sans()
	var strong := VelkaStyle.serif_bold() if serif else VelkaStyle.sans_semibold()
	var text := String(block["text"])
	match String(block["t"]):
		"h3":
			return _h3(text, serif)
		"lede":
			return _margin(_para(text, regular, 14, PAPER_LEDE, 23.12), 0, 0, 0, 0)
		"quote":
			# 사건 기록 (시안 .report-text: 왼쪽 3px 선)
			var frame := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(PAPER_TEXT, 0.2)
			style.border_width_left = 3
			style.content_margin_left = 17.4
			frame.add_theme_stylebox_override("panel", style)
			frame.add_child(_para(text, regular, 14, PAPER_TEXT, 25.92))
			return _margin(frame, 0, 6.4, 0, 14.4)
		"memo":
			# 협회 메모 · 후속 상태 (시안 .report-memo: 굵은 라벨 + 본문)
			var rich := _rich("[font=%s]%s[/font]  %s" % [strong.resource_path, _esc(String(block["label"])), _esc(text)], regular, 14, PAPER_TEXT, 23.12)
			# 시안 margin 0.4rem 0 — 이어지는 메모끼리는 여백이 겹친다
			return _margin(rich, 0, 3.2, 0, 3.2)
		"item":
			return _margin(_para("•  " + text, regular, 14, PAPER_TEXT, 23.12), 14.4, 0, 0, 0)
	return _margin(_para(text, regular, 14, PAPER_TEXT, 25.92), 0, 0, 0, 6.4)


## 구역 소제목 (시안 .paper h3): 위 25.6 · 아래 6.4 여백, 글 아래 1px 선
func _h3(text: String, serif: bool) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(PAPER_TEXT, 0.25)
	style.border_width_bottom = 1
	style.content_margin_bottom = 5.8
	frame.add_theme_stylebox_override("panel", style)
	var label := _text(text, VelkaStyle.serif_bold() if serif else VelkaStyle.sans_semibold(), 15, PAPER_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(label)
	var wrap := _margin(frame, 0, 25.6, 0, 6.4)
	wrap.set_meta("label", label)
	return wrap


## 종이 위 작은 머리 (시안 .margin-label)
func _margin_label(text: String) -> Control:
	return _margin(_text(text, VelkaStyle.spaced(VelkaStyle.mono(), 1), 10, Color(PAPER_TEXT, 0.5)), 0, 16, 0, 0)


# --- 손글씨 필기 (시안 HandNotes / .under-notes) ------------------------------------

## 필기 묶음: 왼쪽 2px 옅은 핏빛 선, 필기마다 살짝 기울임(-0.6° / 짝수 0.5° + 6.4px). 협회장 필기는 상자 안에, 기울이지 않는다.
func _notes_node(notes: Array, indent: float) -> Control:
	var frame := PanelContainer.new()
	frame.name = "UnderNotes"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(BLOOD, 0.3)
	style.border_width_left = 2
	style.content_margin_left = 16.4
	frame.add_theme_stylebox_override("panel", style)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	frame.add_child(list)
	for i in notes.size():
		var note: Dictionary = notes[i]
		var hand: Dictionary = note["hand"]
		var font: Font = VelkaStyle.sans() if print_handwriting else VelkaStyle.font(String(hand["font"]))
		var size := 15 if print_handwriting else int(hand.get("size", 18))
		var card := VBoxContainer.new()
		card.name = "HandNote"
		card.add_theme_constant_override("separation", 0)
		var text := _text(String(note["text"]), font, size, Color(String(hand["ink"])))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line_height(text, font, size, size * 1.25)
		card.add_child(text)
		var sign := _text(String(note["sign"]), VelkaStyle.sans(), 10, Color(PAPER_TEXT, 0.55))
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(_margin(sign, 0, 4, 0, 0))
		if bool(hand.get("boxed", false)):
			var box := PanelContainer.new()
			var boxed := StyleBoxFlat.new()
			boxed.bg_color = Color(0, 0, 0, 0)
			boxed.border_color = Color(107 / 255.0, 87 / 255.0, 109 / 255.0, 0.55)
			boxed.set_border_width_all(1)
			boxed.content_margin_left = 12.2
			boxed.content_margin_right = 12.2
			boxed.content_margin_top = 9
			boxed.content_margin_bottom = 9
			box.add_theme_stylebox_override("panel", boxed)
			box.add_child(card)
			list.add_child(box)
		else:
			var tilt := TiltBox.new()
			var even := i % 2 == 1
			tilt.degrees = 0.5 if even else -0.6
			tilt.shift = Vector2(6.4, 0) if even else Vector2.ZERO
			tilt.add_child(card)
			list.add_child(tilt)
	return _margin(frame, indent, 8, 0, 1.6)


## 필기의 점검용 BBCode (글꼴 경로 · 크기 · 잉크 + 서명)
func _notes_text(notes: Array) -> String:
	var out := ""
	for note in notes:
		var hand: Dictionary = note["hand"]
		var font_path := VelkaStyle.FONT_SANS if print_handwriting else String(hand["font"])
		out += "[font=%s][font_size=%d][color=%s]%s[/color][/font_size][/font]\n%s\n" % [
				font_path, int(hand.get("size", 18)), hand["ink"], _esc(String(note["text"])), _esc(String(note["sign"]))]
	return out


func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


# --- 목표·확인 (시안 .goals-page) -------------------------------------------------

## 진행 기록: 지금 목표(▶ 금빛) 다음에 지나온 목표(✓ 청록)를 최근 것부터. 확인한 사실: 문서 확보 · 규칙 확정 · 대조 상태
func _render_goals() -> void:
	var log := _objective_log()
	_clear(_goal_list)
	if log.is_empty():
		var empty := _text("아직 정해진 목표가 없다.", VelkaStyle.sans(), 13, Color(INK, 0.5))
		empty.name = "EmptyGoals"
		_goal_list.add_child(empty)
	else:
		_goal_list.add_child(_goal_row(String(log[-1]), true))
	for i in range(log.size() - 2, -1, -1):
		_goal_list.add_child(_goal_row(String(log[i]), false))
	var known := 0
	var verified := 0
	for r in RuleManager.get_all_rules():
		if bool(r.get("discovered", false)):
			known += 1
			if RuleManager.is_verified(String(r["id"])):
				verified += 1
	var doc_count := 0
	for doc in _docs:
		if _unlocked.has(String(doc["id"])):
			doc_count += 1
	_clear(_fact_chips)
	_fact_chips.add_child(_fact_chip("문서 확보 %d" % doc_count))
	_fact_chips.add_child(_fact_chip("규칙 확정 %d / %d" % [verified, known]))
	_fact_chips.add_child(_fact_chip("대조 완료" if known > 0 and verified >= known else "현장 대조 중"))


## 목표 한 줄 (시안 .goal-row): 지금 목표는 금빛 테두리 + 옅은 금빛 바탕 + ▶, 지난 목표는 흐린 글자 + 청록 ✓
func _goal_row(text: String, current: bool) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GOLD, 0.06) if current else Color(0, 0, 0, 0)
	style.border_color = Color(GOLD, 0.55) if current else Color(INK, 0.12)
	style.set_border_width_all(1)
	style.content_margin_left = 15.4
	style.content_margin_right = 15.4
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 13)
	row.add_child(line)
	var mark := _text("▶" if current else "✓", VelkaStyle.sans(), 11, GOLD if current else TEAL)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(mark)
	var l := _text(text, VelkaStyle.sans(), 14, INK if current else Color(INK, 0.55))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(l)
	return row


## 확인한 사실 칩 (시안 .fact-chips span)
func _fact_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(INK, 0.22)
	style.set_border_width_all(1)
	style.content_margin_left = 10.6
	style.content_margin_right = 10.6
	style.content_margin_top = 6.6
	style.content_margin_bottom = 6.6
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_text(text, VelkaStyle.sans(), 12, INK))
	return chip


# --- 수집 기록 (시안 .collect-page) -----------------------------------------------

## 입수한 자료 카드 + 입수 전 문서마다 미발견 카드, 그 아래 소지품 카드
func _render_inventory() -> void:
	_clear(_inventory_box)
	_inventory_box.add_child(_page_caption("입수한 자료"))
	var grid := _card_grid()
	_inventory_box.add_child(grid)
	var missing := 0
	for doc in _docs:
		var id := String(doc["id"])
		if not _unlocked.has(id):
			var name_text := "LockedDocs" if missing == 0 else "LockedDocs_%d" % missing
			grid.add_child(_doc_card(name_text, "", "미발견", "???", "아직 찾지 못한 자료", true))
			missing += 1
			continue
		var kind := String(doc.get("kind", ""))
		var card := _doc_card("Doc_" + id, "kind-rule" if kind == "rulebook" else "kind-report", "규칙서" if kind == "rulebook" else "협회 자료",
				String(doc["title"]), "%s · %d / %d쪽" % [String(doc.get("subtitle", "")), get_pages(id).size(), (doc.get("pages", []) as Array).size()], false)
		(card.get_meta("button") as Button).pressed.connect(_open_document.bind(id))
		grid.add_child(card)
	_fill_grid(grid)
	_inventory_box.add_child(_spacer(22.4 - 10))

	# 소지품 (손전등 배터리는 시안에 없어서 머리 줄에 붙인다)
	var items: Array = InventoryManager.items
	_inventory_box.add_child(_page_caption("소지품  ·  손전등 배터리 %d%%" % roundi(InventoryManager.battery_level / maxf(InventoryManager.max_battery, 1.0) * 100.0)))
	if items.is_empty():
		var empty := _text("가진 물건이 없다.", VelkaStyle.sans(), 12, Color(INK, 0.5))
		empty.name = "EmptyInventory"
		_inventory_box.add_child(empty)
		return
	var item_grid := _card_grid()
	_inventory_box.add_child(item_grid)
	for item in items:
		var name_text := String(item)
		var desc := String(_item_info.get(name_text, {}).get("description", ""))
		item_grid.add_child(_doc_card("Item_" + name_text, "item", "", name_text, desc, false))
	_fill_grid(item_grid)


## 문서 카드를 누르면 그 문서가 있는 탭에서 연다
func _open_document(document_id: String) -> void:
	select_document(document_id)


func _page_caption(text: String) -> Control:
	var label := _text(text, VelkaStyle.spaced(VelkaStyle.mono(), 1), 11, Color(INK, 0.45))
	return _margin(label, 0, 6.4, 0, 11.2)


## 시안 auto-fill 격자처럼 카드가 한 줄에 다 차지 않아도 칸 너비는 같게: 빈 칸을 채워 둔다
func _fill_grid(grid: GridContainer) -> void:
	while grid.get_child_count() % grid.columns != 0 or grid.get_child_count() == 0:
		var filler := Control.new()
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(filler)


func _card_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


## 자료 카드 (시안 .doc-card): 종류 칩 + 제목 + 작은 설명. 마우스 오버 시 핏빛 테두리. 미발견은 점선 + 45%.
func _doc_card(node_name: String, kind: String, chip_text: String, title: String, desc: String, missing: bool) -> Control:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clickable := not missing and kind != "item"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	var normal: StyleBox
	if missing:
		var dashed := DashedStyle.new()
		dashed.color = Color(INK, 0.2)
		dashed.bg = Color(INK, 0.03)
		normal = dashed
		holder.modulate.a = 0.45
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(INK, 0.03)
		flat.border_color = Color(INK, 0.2)
		flat.set_border_width_all(1)
		normal = flat
	var hover := normal
	if clickable:
		hover = (normal as StyleBoxFlat).duplicate()
		(hover as StyleBoxFlat).border_color = BLOOD
	for state in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed"]:
		b.add_theme_stylebox_override(state, hover)
	holder.add_child(b)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	if not chip_text.is_empty():
		var chip := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0, 0, 0, 0)
		cs.border_color = BLOOD if kind == "kind-report" else Color(INK, 0.3)
		cs.set_border_width_all(1)
		cs.content_margin_left = 7.4
		cs.content_margin_right = 7.4
		cs.content_margin_top = 2.6
		cs.content_margin_bottom = 2.6
		chip.add_theme_stylebox_override("panel", cs)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.add_child(_text(chip_text, VelkaStyle.sans(), 10, INK if kind == "kind-report" else Color(INK, 0.7)))
		column.add_child(chip)
	var t := _text(title, VelkaStyle.sans_medium(), 16, INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(t)
	if not desc.strip_edges().is_empty():
		var d := _text(desc.strip_edges(), VelkaStyle.sans(), 12, Color(INK, 0.5))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(d)
	holder.add_child(_margin(column, 15.4, 15.4, 15.4, 15.4))
	_ignore_mouse(column)
	if kind == "item" or missing:
		holder.name = node_name
	else:
		holder.name = node_name + "_Card"
		b.name = node_name
	holder.set_meta("button", b)
	return holder


# --- 스크롤 · 탭 전환 움직임 ---------------------------------------------------------

func _scroll_body(amount: float) -> void:
	var scroll: ScrollContainer = null
	if _tab == Tab.COLLECTION:
		scroll = _inventory_view
	elif _tab == Tab.GOALS:
		scroll = _goals_view as ScrollContainer
	elif _doc_scroll.visible:
		scroll = _doc_scroll
	if scroll == null or not scroll.is_visible_in_tree():
		return
	var bar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(clampf(scroll.scroll_vertical + amount, 0.0, maxf(bar.max_value - bar.page, 0.0)))


## 지금 쪽이 보이게 스크롤한다 (규칙서: 그 구역의 위치, 보고서: 맨 위)
func _focus_page() -> void:
	if not is_inside_tree() or _doc_scroll == null:
		return
	await get_tree().process_frame
	var index := get_current_page_index()
	var y := 0.0
	if _tab == Tab.RULEBOOK and index > 0 and index < _section_nodes.size() and is_instance_valid(_section_nodes[index]):
		var target := _section_nodes[index]
		y = target.get_global_rect().position.y - _sheet_holder.get_global_rect().position.y
	_doc_scroll.scroll_vertical = int(y)
	_update_thumb()


## 종이 스크롤 위치를 오른쪽 여백의 얇은 막대로 보여 준다 (스크롤 막대는 시안처럼 공간을 차지하지 않는다)
func _update_thumb() -> void:
	if _scroll_thumb == null or _doc_scroll == null:
		return
	var bar := _doc_scroll.get_v_scroll_bar()
	var track := _doc_scroll.size.y - 38.4
	if bar.max_value <= bar.page + 1.0 or track <= 0.0:
		_scroll_thumb.visible = false
		return
	_scroll_thumb.visible = true
	var h := maxf(track * bar.page / bar.max_value, 24.0)
	_scroll_thumb.size = Vector2(3, h)
	_scroll_thumb.position = Vector2(_doc_scroll.position.x + _doc_scroll.size.x - 12, _doc_scroll.position.y + 19.2 + (track - h) * bar.value / maxf(bar.max_value - bar.page, 1.0))


## 시안 .journal-body { animation: page-in 0.25s ease-out } — 투명 + 4px 아래에서 제자리로
func _play_page_in() -> void:
	if _view_tween:
		_view_tween.kill()
	var view: Control = _goals_view if _tab == Tab.GOALS else _inventory_view if _tab == Tab.COLLECTION else _docs_view
	# position 대신 위아래 여백만 움직인다 (첫 배치 전에 position 을 쓰면 최소 크기만큼 오른쪽 여백이 남는다)
	for v in [_goals_view, _inventory_view, _docs_view]:
		(v as Control).modulate.a = 1.0
		(v as Control).offset_top = 0.0
		(v as Control).offset_bottom = 0.0
	if _reduce_effects() or not is_inside_tree():
		return
	view.modulate.a = 0.0
	view.offset_top = 4.0
	view.offset_bottom = 4.0
	_view_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_view_tween.tween_property(view, "modulate:a", 1.0, PAGE_IN)
	_view_tween.tween_property(view, "offset_top", 0.0, PAGE_IN)
	_view_tween.tween_property(view, "offset_bottom", 0.0, PAGE_IN)


# --- UI 만들기 ----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "JournalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# 시안 .journal-overlay: rgba(6,5,5,0.8) + blur(3px)
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(6 / 255.0, 5 / 255.0, 5 / 255.0, 0.8)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 1.6).rgb;
	COLOR = vec4(mix(c, vec3(6.0, 5.0, 5.0) / 255.0, 0.8), 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	dimmer.material = mat
	_root.add_child(dimmer)

	var window := WindowBg.new()
	window.name = "JournalPanel"
	window.position = WINDOW_RECT.position
	window.size = WINDOW_RECT.size
	_root.add_child(window)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 1
	page.offset_top = 1
	page.offset_right = -1
	page.offset_bottom = -1
	page.add_theme_constant_override("separation", 0)
	window.add_child(page)
	page.add_child(_build_header())
	page.add_child(_hline(Color(INK, 0.12)))
	_body = Control.new()
	_body.name = "JournalBody"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	page.add_child(_body)
	_body.add_child(_build_goals_view())
	_body.add_child(_build_doc_view())
	_body.add_child(_build_inventory_view())
	page.add_child(_hline(Color(INK, 0.1)))
	page.add_child(_build_footer())


## 머리 (시안 .journal-head): 왼쪽 머리말 + 제목, 탭, 오른쪽 닫기 ×
func _build_header() -> Control:
	var margin := MarginContainer.new()
	margin.name = "Head"
	margin.custom_minimum_size.y = 73
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(column)
	_chapter_label = _text("FIELD RECORD", VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, TEAL)
	column.add_child(_margin(_chapter_label, 0, 0, 0, 5))
	var title := _text("조사 기록", VelkaStyle.serif(), 23, INK)
	title.name = "JournalTitle"
	column.add_child(_margin(title, 0, 0, 0, 14.4))
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 0)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(tabs)
	for i in TAB_NAMES.size():
		tabs.add_child(_build_tab(i))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.text = "×"
	close_button.tooltip_text = "조사 기록 닫기"
	close_button.custom_minimum_size = Vector2(44.8, 44.8)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_override("font", VelkaStyle.sans())
	close_button.add_theme_font_size_override("font_size", 19)
	for state in ["font_color", "font_pressed_color", "font_focus_color"]:
		close_button.add_theme_color_override(state, SCREEN_INK)
	close_button.add_theme_color_override("font_hover_color", TEAL)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0, 0, 0, 0)
	cs.border_color = ICON_LINE
	cs.set_border_width_all(1)
	var ch := cs.duplicate() as StyleBoxFlat
	ch.border_color = TEAL
	for state in ["normal", "disabled", "focus"]:
		close_button.add_theme_stylebox_override(state, cs)
	for state in ["hover", "pressed"]:
		close_button.add_theme_stylebox_override(state, ch)
	close_button.pressed.connect(close)
	# 머리 위 여백(17.6)을 뺀 높이의 가운데: 시안 align-self: center
	row.add_child(_margin(close_button, 0, 0, 0, 2))
	return margin


## 탭 하나 (시안 .journal-tabs button): 번호 small · 이름 · em(수집 기록 개수) · 새 쪽 ●
func _build_tab(i: int) -> Control:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var b := Button.new()
	b.name = "Tab_%d" % i
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.border_width_bottom = 2
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, style)
	holder.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var num := _text(str(i + 1), VelkaStyle.mono(), 10, INK)
	num.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_margin(num, 0, 0, 0, 2))
	var name_label := _text(TAB_NAMES[i], VelkaStyle.sans(), 14, INK)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(name_label)
	var em := PanelContainer.new()
	var es := StyleBoxFlat.new()
	es.bg_color = Color(0, 0, 0, 0)
	es.border_color = INK
	es.set_border_width_all(1)
	es.content_margin_left = 6.6
	es.content_margin_right = 6.6
	es.content_margin_top = 1
	es.content_margin_bottom = 1
	em.add_theme_stylebox_override("panel", es)
	var em_label := _text("0", VelkaStyle.sans(), 10, INK)
	em.add_child(em_label)
	em.size_flags_vertical = Control.SIZE_SHRINK_END
	var em_wrap := _margin(em, 0, 0, 0, 1)
	row.add_child(em_wrap)
	var dot := _text("●", VelkaStyle.sans(), 8, TEAL)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	holder.add_child(_margin(row, 16, 11.2, 16, 15.6))
	_ignore_mouse(row)
	b.pressed.connect(show_tab.bind(i))
	b.mouse_entered.connect(func():
		_hover_tab = i
		_render_tabs())
	b.mouse_exited.connect(func():
		if _hover_tab == i:
			_hover_tab = -1
		_render_tabs())
	_tab_buttons.append(b)
	_tab_parts.append({"num": num, "name": name_label, "em": em, "em_wrap": em_wrap, "em_label": em_label, "dot": dot})
	return holder


## 목표·확인 (시안 .goals-page: 1.3fr | 1fr, 사이 2rem)
func _build_goals_view() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "GoalsView"
	_fill(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.visible = false
	_goals_view = scroll
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 32)
	scroll.add_child(_margin(row, 24, 19.2, 24, 19.2))
	(row.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	left.add_child(_page_caption("진행 기록"))
	_goal_list = VBoxContainer.new()
	_goal_list.add_theme_constant_override("separation", 7)
	left.add_child(_goal_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	right.add_child(_page_caption("확인한 사실"))
	_fact_chips = HFlowContainer.new()
	_fact_chips.add_theme_constant_override("h_separation", 6)
	_fact_chips.add_theme_constant_override("v_separation", 6)
	right.add_child(_fact_chips)
	var hint := _para("수칙대로 움직이면 규칙이 확정됩니다. 어기면 대가를 치르고, 그 결과도 기록됩니다.", VelkaStyle.sans(), 13, Color(INK, 0.5), 21.76)
	right.add_child(_margin(hint, 0, 16, 0, 0))
	return _goals_view


## 규칙서·보고서 (시안 .doc-layout: 12rem 목록 | 종이, 사이 1.25rem)
func _build_doc_view() -> Control:
	var view := Control.new()
	view.name = "DocView"
	_fill(view)
	view.visible = false
	_docs_view = view

	var index_scroll := ScrollContainer.new()
	index_scroll.name = "DocIndex"
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	index_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	index_scroll.position = Vector2(24, 19.2)
	index_scroll.size = Vector2(192, 624.8 - 19.2)
	view.add_child(index_scroll)
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size.x = 192
	_list_box.add_theme_constant_override("separation", 2)
	index_scroll.add_child(_list_box)

	_doc_scroll = ScrollContainer.new()
	_doc_scroll.name = "PaperScroll"
	_doc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_doc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_doc_scroll.position = Vector2(24 + 192 + 20 - 2, 0)
	_doc_scroll.size = Vector2(1086 - (24 + 192 + 20 - 2), 624.8)
	view.add_child(_doc_scroll)
	_sheet_holder = MarginContainer.new()
	_sheet_holder.name = "PaperHolder"
	_sheet_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_holder.add_theme_constant_override("margin_left", 2)
	_sheet_holder.add_theme_constant_override("margin_right", 24)
	_sheet_holder.add_theme_constant_override("margin_top", 19)
	_sheet_holder.add_theme_constant_override("margin_bottom", 40)
	_doc_scroll.add_child(_sheet_holder)
	_doc_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _update_thumb())
	_doc_scroll.get_v_scroll_bar().changed.connect(_update_thumb)

	_scroll_thumb = ColorRect.new()
	_scroll_thumb.name = "ScrollThumb"
	_scroll_thumb.color = Color(INK, 0.16)
	_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_thumb.visible = false
	view.add_child(_scroll_thumb)

	_empty_label = _text("", VelkaStyle.sans(), 13, Color(INK, 0.5))
	_empty_label.name = "EmptyLabel"
	_empty_label.position = Vector2(24 + 192 + 20, 19.2)
	_empty_label.size = Vector2(826, 60)
	_empty_label.visible = false
	view.add_child(_empty_label)
	return view


## 새 종이 (시안 .paper): 바랜 종이 #e6dfcd + 붉은 얼룩 · 갈색 얼룩 · 28px 줄, 안쪽 여백 32 / 35.2 / 38.4
func _new_sheet() -> VBoxContainer:
	_clear(_sheet_holder)
	var paper := PanelContainer.new()
	paper.name = "Paper"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.border_color = Color(0, 0, 0, 0.4)
	frame.set_border_width_all(1)
	frame.set_expand_margin_all(1)
	frame.set_content_margin_all(0)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 24
	frame.shadow_offset = Vector2(0, 18)
	paper.add_theme_stylebox_override("panel", frame)
	paper.add_child(PaperBg.new())
	var sheet := VBoxContainer.new()
	sheet.name = "Sheet"
	sheet.add_theme_constant_override("separation", 0)
	paper.add_child(_margin(sheet, 35.2, 32, 35.2, 38.4))
	_sheet_holder.add_child(paper)
	return sheet


func _build_inventory_view() -> Control:
	_inventory_view = ScrollContainer.new()
	_inventory_view.name = "InventoryView"
	_fill(_inventory_view)
	_inventory_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_view.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_inventory_view.visible = false
	_inventory_box = VBoxContainer.new()
	_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_box.add_theme_constant_override("separation", 0)
	var margin := _margin(_inventory_box, 24, 19.2, 24, 19.2)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_view.add_child(margin)
	return _inventory_view


## 아래 띠 (시안 .journal-foot): [Q][E] 탭 이동 · [1]–[4] 바로 가기 · [Tab] 닫기 (+ 문서 탭에서 쪽 · 문서 키, 정자체 보기)
func _build_footer() -> Control:
	var margin := MarginContainer.new()
	margin.name = "Foot"
	margin.custom_minimum_size.y = 34.2
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	row.add_child(_foot_span([["Q", "E"]], "탭 이동"))
	row.add_child(_foot_span([["1"], "–", ["4"]], "바로 가기"))
	row.add_child(_foot_span([["Tab"]], "닫기"))
	var page_keys := _foot_span([["←", "→"]], "쪽")
	var doc_keys := _foot_span([["↑", "↓"]], "문서")
	row.add_child(page_keys)
	row.add_child(doc_keys)
	_foot_doc_keys = [page_keys, doc_keys]
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_hand_toggle = Button.new()
	_hand_toggle.name = "HandwritingToggle"
	_hand_toggle.focus_mode = Control.FOCUS_NONE
	_hand_toggle.flat = true
	_hand_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_toggle.add_theme_font_override("font", VelkaStyle.sans())
	_hand_toggle.add_theme_font_size_override("font_size", 11)
	_hand_toggle.add_theme_color_override("font_color", Color(INK, 0.45))
	_hand_toggle.add_theme_color_override("font_hover_color", INK)
	_hand_toggle.add_theme_color_override("font_pressed_color", INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_hand_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_hand_toggle.pressed.connect(func(): set_print_handwriting(not print_handwriting))
	row.add_child(_hand_toggle)
	return margin


## 아래 띠 한 묶음: 키캡들 + 설명. parts 의 배열은 키캡, 글은 그대로 (예: [["1"], "–", ["4"]])
func _foot_span(parts: Array, caption: String) -> Control:
	var span := HBoxContainer.new()
	span.add_theme_constant_override("separation", 0)
	span.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for part in parts:
		if part is Array:
			for key in part:
				span.add_child(_margin(_kbd(String(key)), 2.4, 0, 2.4, 0))
		else:
			span.add_child(_text(String(part), VelkaStyle.sans(), 11, Color(INK, 0.45)))
	span.add_child(_text(" " + caption, VelkaStyle.sans(), 11, Color(INK, 0.45)))
	return span


## 시안 kbd: 1px 테두리(아래 2px), 나눔고딕코딩 9.92px, 최소 폭 1.3em
func _kbd(text: String) -> Control:
	var cap := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(INK, 0.35)
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.content_margin_left = 5.8
	box.content_margin_right = 5.8
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", box)
	cap.custom_minimum_size = Vector2(16.6, 13)
	# 나눔고딕코딩에는 화살표가 없어서 화살표 키캡은 Pretendard 로 쓴다
	var ascii := true
	for ch in text:
		ascii = ascii and ch.unicode_at(0) < 128
	var l := _text(text, VelkaStyle.mono() if ascii else VelkaStyle.sans(), 10, Color(INK, 0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


# --- 작은 도우미 ---------------------------------------------------------------

func _text(text: String, f: Font, size: int, color: Color) -> Label:
	var l := VelkaStyle.label(text, f, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 줄 높이(px)를 시안 line-height 에 맞춘다
func _line_height(c: Control, f: Font, size: int, lh: float) -> void:
	var extra := int(round(lh - f.get_height(size)))
	if c is RichTextLabel:
		c.add_theme_constant_override("line_separation", extra)
	else:
		c.add_theme_constant_override("line_spacing", extra)


## 시안 문단: 줄 높이 + 위아래 반쪽 행간
func _para(text: String, f: Font, size: int, color: Color, lh: float) -> Control:
	var l := _text(text, f, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_height(l, f, size, lh)
	var half := maxf((lh - f.get_height(size)) * 0.5, 0.0)
	return _margin(l, 0, half, 0, half)


## BBCode 문단 (위반 조항 잉크 번짐 · 굵은 라벨)
func _rich(bbcode: String, f: Font, size: int, color: Color, lh: float) -> Control:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.selection_enabled = false
	rich.focus_mode = Control.FOCUS_NONE
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", f)
	rich.add_theme_font_size_override("normal_font_size", size)
	rich.add_theme_font_size_override("bold_font_size", size)
	rich.add_theme_color_override("default_color", color)
	_line_height(rich, f, size, lh)
	rich.text = bbcode
	var half := maxf((lh - f.get_height(size)) * 0.5, 0.0)
	var m := _margin(rich, 0, half, 0, half)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return m


func _margin(child: Control, left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(round(left)))
	m.add_theme_constant_override("margin_top", int(round(top)))
	m.add_theme_constant_override("margin_right", int(round(right)))
	m.add_theme_constant_override("margin_bottom", int(round(bottom)))
	m.add_child(child)
	return m


## 부모를 꽉 채운다 (set_anchors_and_offsets_preset 은 부모 크기가 정해지기 전이면 최소 크기만큼 오른쪽 여백을 남긴다)
func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _hline(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## 창 바탕 (시안 .journal 통합 테마): 그림자 0 30px 80px · 세로 그라데이션 #12171b→#0c1013 · 1px #263036 테두리 ·
## 윗선 #3a454c · 모서리 6px
class WindowBg extends Control:
	const RADIUS := 6.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0)
		shadow.shadow_color = Color(0, 0, 0, 0.6)
		shadow.shadow_size = 40
		shadow.shadow_offset = Vector2(0, 30)
		shadow.set_corner_radius_all(int(RADIUS))
		draw_style_box(shadow, Rect2(Vector2.ZERO, size))
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var top := Color("#12171b")
		var bottom := Color("#0c1013")
		var centers := [Vector2(size.x - RADIUS, RADIUS), Vector2(size.x - RADIUS, size.y - RADIUS), Vector2(RADIUS, size.y - RADIUS), Vector2(RADIUS, RADIUS)]
		for corner in 4:
			for step in 7:
				var angle := deg_to_rad(-90.0 + corner * 90.0 + step * 15.0)
				var p: Vector2 = centers[corner] + Vector2(cos(angle), sin(angle)) * RADIUS
				points.append(p)
				colors.append(top.lerp(bottom, clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)))
		draw_polygon(points, colors)
		var border := StyleBoxFlat.new()
		border.bg_color = Color(0, 0, 0, 0)
		border.border_color = Color("#263036")
		border.set_border_width_all(1)
		border.set_corner_radius_all(int(RADIUS))
		draw_style_box(border, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(RADIUS * 0.5, 0, size.x - RADIUS, 1), Color("#3a454c"))


## 바랜 종이 (시안 .paper 통합 테마): 바탕 #e6dfcd · 아래에서 28px 마다 옅은 줄 · 왼쪽 아래 갈색 얼룩 · 오른쪽 위 붉은 얼룩
class PaperBg extends Control:
	var _red: GradientTexture2D
	var _brown: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		_red = _radial(Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.07))
		_brown = _radial(Color(60 / 255.0, 40 / 255.0, 20 / 255.0, 0.12))

	static func _radial(c: Color) -> GradientTexture2D:
		var g := Gradient.new()
		g.set_color(0, c)
		g.set_color(1, Color(c, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		return t

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#e6dfcd"))
		var y := size.y - 28.0
		while y >= 0.0:
			draw_rect(Rect2(0, y, size.x, 1), Color(42 / 255.0, 37 / 255.0, 34 / 255.0, 0.05))
			y -= 28.0
		# radial-gradient(circle at 10% 90%, …, transparent 45%) — 반지름은 가장 먼 모서리까지의 45%
		var c2 := Vector2(size.x * 0.1, size.y * 0.9)
		var r2 := 0.45 * Vector2(size.x * 0.9, size.y * 0.9).length()
		draw_texture_rect(_brown, Rect2(c2 - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false)
		var c1 := Vector2(size.x * 0.8, size.y * 0.1)
		var r1 := 0.40 * Vector2(size.x * 0.8, size.y * 0.9).length()
		draw_texture_rect(_red, Rect2(c1 - Vector2(r1, r1), Vector2(r1, r1) * 2.0), false)


## 위반 조항 오른쪽 위의 번진 잉크 얼룩 (시안 .paper-rule.is-violated::after: 오른쪽 6% · 위 10%, 5rem x 2.2rem)
class InkBlot extends Control:
	var _tex: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.set_color(0, Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.22))
		g.set_offset(1, 0.7)
		g.set_color(1, Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.0))
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.4, 0.5)
		_tex.fill_to = Vector2(0.4 + 0.78, 0.5)
		_tex.width = 128
		_tex.height = 64

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		# 패널 안쪽 여백(위 11.2) 기준으로 놓인 노드이므로 조항 상자 전체 기준으로 바꿔 놓는다
		var full_h := size.y + 23.4
		draw_texture_rect(_tex, Rect2(size.x * 0.94 - 80.0, -11.2 + full_h * 0.1, 80.0, 35.2), false)


## 점선 테두리 (시안 border-style: dashed). sides = [위, 오른쪽, 아래, 왼쪽]
class DashedStyle extends StyleBox:
	var color := Color.WHITE
	var bg := Color(0, 0, 0, 0)
	var width := 1.0
	var dash := 3.0
	var gap := 3.0
	var sides: Array = [true, true, true, true]

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if bg.a > 0.0:
			RenderingServer.canvas_item_add_rect(to_canvas_item, rect, bg)
		if sides[0]:
			_dash_h(to_canvas_item, rect.position.x, rect.end.x, rect.position.y)
		if sides[2]:
			_dash_h(to_canvas_item, rect.position.x, rect.end.x, rect.end.y - width)
		if sides[3]:
			_dash_v(to_canvas_item, rect.position.y, rect.end.y, rect.position.x)
		if sides[1]:
			_dash_v(to_canvas_item, rect.position.y, rect.end.y, rect.end.x - width)

	func _dash_h(item: RID, x0: float, x1: float, y: float) -> void:
		var x := x0
		while x < x1:
			RenderingServer.canvas_item_add_rect(item, Rect2(x, y, minf(dash, x1 - x), width), color)
			x += dash + gap

	func _dash_v(item: RID, y0: float, y1: float, x: float) -> void:
		var y := y0
		while y < y1:
			RenderingServer.canvas_item_add_rect(item, Rect2(x, y, width, minf(dash, y1 - y)), color)
			y += dash + gap


## 자식 하나를 기울여 놓는 상자 (시안 transform: rotate(…) translateX(…)). 컨테이너가 자식의 회전을 지우므로
## 자리를 잡은 뒤에 다시 기울인다.
class TiltBox extends Container:
	var degrees := 0.0
	var shift := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			for c in get_children():
				if c is Control:
					var child := c as Control
					fit_child_in_rect(child, Rect2(Vector2.ZERO, size))
					child.pivot_offset = child.size * 0.5
					child.rotation_degrees = degrees
					child.position += shift

	func _get_minimum_size() -> Vector2:
		var m := Vector2.ZERO
		for c in get_children():
			if c is Control and (c as Control).visible:
				m = m.max((c as Control).get_combined_minimum_size())
		return m
