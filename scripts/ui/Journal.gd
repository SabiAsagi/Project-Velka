extends CanvasLayer

# 프로젝트 벨카 - 조사 기록 수첩 (Tab) — 기본 디자인 0.2 시안 04~07 · 24~28
# 탭 4개: 목표·확인 / 맵 규칙서 / 협회 보고서 / 수집 기록. R(옛 규칙 수첩 키)은 맵 규칙서 탭을 바로 연다.
#   - 목표·확인: 이 장면에서 받은 목표(지금 목표 + 지나온 목표)와, 알게 된 규칙 중 직접 확인한 수.
#   - 규칙서·보고서: 왼쪽 문서 목록 + 오른쪽 종이 문서. 문서와 쪽은 data/journal/documents.json 에 있고,
#     story flag(unlock_flag)나 규칙 발견(unlock_category / categories)으로 열린다. 새로 열리면 HUD에 알린다.
#     입수하지 않은 문서는 제목을 보이지 않고 '미발견'으로만 남긴다.
#   - 규칙서 문서(ruleset)는 본문을 RuleManager 규칙 데이터에서 그린다. 알게 된 규칙에만 상태 표시가 붙는다:
#     진행(미확인·협회 기록 / 추정 / 확정) · 진위(확정된 뒤에만: 정상 / 조건부 / 오염) · 위반 결과.
#   - 필기(사비 메모, 샤무 코멘트, 보고서의 "> [소속 / 이름] …" 줄)는 종이 오른쪽 여백에 각자의 손글씨로 남는다.
#     인물별 손글씨는 HANDS (assets/fonts/hand/, tools/fonts/rebuild_handwriting.py 로 만든 부분 글꼴).
#     서명은 "이름 / 소속" (사비·샤무는 "— 이름"), 협회장의 필기는 상자 안에 남는다.
#     '정자체 보기'를 켜면 손글씨를 읽기 쉬운 글꼴로 보여 준다.
#   - 수집 기록: 입수한 문서(규칙서·협회 자료) 카드 + 미발견 카드, 소지품 카드 (설명은 data/journal/items.json).
#     문서 카드를 누르면 그 문서를 연다.
# 열려 있는 동안에는 탐색 입력이 잠긴다. 키: Tab / Esc 닫기, Q E 또는 1~4 탭, ← → (A D) 쪽, ↑ ↓ 문서, 휠 · W S 스크롤.

signal opened()
signal closed()
## 수첩에 새 문서/쪽이 열렸을 때 (page_title이 비어 있으면 문서 전체)
signal page_unlocked(document_id: String, page_title: String)

enum Tab { GOALS, RULEBOOK, REPORT, COLLECTION }

const LOCK_REASON := "journal"
const DOCUMENTS_PATH := "res://data/journal/documents.json"
const ITEMS_PATH := "res://data/journal/items.json"
const TAB_NAMES: Array[String] = ["목표·확인", "맵 규칙서", "협회 보고서", "수집 기록"]
const TAB_KINDS: Array[String] = ["", "rulebook", "report", ""]
const NOTICE_COLOR := Color(0.95, 0.85, 0.55)

const BODY_SIZE := 24
const NOTE_SIZE := 30
const CHIP_SIZE := 17
const HEAD_INK_RULEBOOK := "#6e1d18"
const HEAD_INK_REPORT := "#26313a"
const QUOTE_INK := "#4b4338"
const CHIP_BG := "#d8d0bc"
const CHIP_INK := "#3c4650"
const VERACITY_INK := {"정상": "#2f6b4c", "조건부": "#8a6512", "오염": "#9b2c22"}
const VIOLATION_INK := "#8e2b1f"
const ASSOCIATION_INK := "#26597a"
## 인물별 손글씨 (기본 디자인 0.2): 글꼴 · 잉크 · 이름 · 소속. 필기 서명의 이름으로 고른다.
const HAND_DIR := "res://assets/fonts/hand/"
const HANDS := {
	"sabi": {"font": HAND_DIR + "Sabi-Hand.ttf", "ink": "#326B7A", "name": "사비 아사기", "dept": ""},
	"shamu": {"font": HAND_DIR + "Shamu-Hand.ttf", "ink": "#8A592E", "name": "카즈네 샤무", "dept": ""},
	"kwon": {"font": HAND_DIR + "Kwon-Hand.ttf", "ink": "#4A575D", "name": "권지혁", "dept": "전투대응부"},
	"baek": {"font": HAND_DIR + "Baek-Hand.ttf", "ink": "#6B576D", "name": "백윤서", "dept": "협회장", "boxed": true},
	"seo": {"font": HAND_DIR + "Seo-Hand.ttf", "ink": "#5B6C4F", "name": "서유림", "dept": "보호관리부"},
	"yu": {"font": HAND_DIR + "Yu-Hand.ttf", "ink": "#375C69", "name": "유가온", "dept": "정보조사부"},
	"han": {"font": HAND_DIR + "Han-Hand.ttf", "ink": "#8A6242", "name": "한재윤", "dept": "기술지원부"},
}
const HAND_SABI: Dictionary = HANDS["sabi"]
const HAND_SHAMU: Dictionary = HANDS["shamu"]
## 이름이 정해진 인물이 아닌 협회 대원(기록관리팀 등)의 필기
const HAND_ASSOCIATION := {"font": "res://assets/fonts/Gaegu-Regular.ttf", "ink": "#4f5878", "name": "", "dept": ""}
## 문단 사이의 좁은 빈 줄 (빈 줄 하나를 통째로 넣으면 너무 벌어진다)
const GAP := "[font_size=10] [/font_size]\n"

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
var _place_label: Label
var _tab_buttons: Array[Button] = []
var _hand_toggle: Button
var _list_column: Control
var _list_box: VBoxContainer
var _doc_view: Control
var _paper: PanelContainer
var _doc_source: Label
var _doc_title: Label
var _doc_subtitle: Label
var _stamp: Label
var _page_title: Label
var _body: RichTextLabel
var _notes_column: Control
var _notes: RichTextLabel
var _notes_head: Label
var _empty_label: Label
var _prev_button: Button
var _next_button: Button
var _page_label: Label
var _goals_view: Control
var _goal_now: Label
var _goal_list: VBoxContainer
var _fact_count: Label
var _fact_total: Label
var _fact_bar: ProgressBar
var _fact_chips: HBoxContainer
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
func open(tab: int = -1) -> void:
	if is_open() or not can_open():
		return
	_tab = tab if tab >= 0 and tab < TAB_NAMES.size() else _default_tab()
	_scan_unlocks(true)
	_render()
	_root.visible = true
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


## 문서를 펼친다. 문서가 없거나 아직 입수하지 않았으면 false
func select_document(document_id: String) -> bool:
	var doc := _doc_by_id(document_id)
	if doc.is_empty() or not _unlocked.has(document_id):
		return false
	var tab := TAB_KINDS.find(String(doc.get("kind", "")))
	if tab < 0:
		return false
	_tab = tab
	_selected_doc[tab] = document_id
	_render()
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
	var count := get_pages(id).size()
	_page_of[id] = clampi(int(_page_of.get(id, 0)) + delta, 0, maxi(count - 1, 0))
	_render()


## 지금 쪽의 BBCode (본문 + 여백 필기, 테스트·점검용)
func get_page_text() -> String:
	if _body == null:
		return ""
	return _body.text + ("\n" + _notes.text if _notes and _notes_column.visible else "")


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


## "소속 / 이름" → "이름 / 소속" (시안 0.2 서명 표기)
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


## 이 종류에서 아직 입수하지 않은 문서 수 (제목은 드러내지 않는다)
func _locked_count(kind: String) -> int:
	var count := 0
	for doc in _docs:
		if String(doc.get("kind", "")) == kind and not _unlocked.has(String(doc["id"])):
			count += 1
	return count


func _objective_log() -> Array:
	var hud := get_tree().get_first_node_in_group("rule_warning_listener")
	if hud and "objective_log" in hud:
		return hud.objective_log
	return []


# --- 그리기 -----------------------------------------------------------------

func _render() -> void:
	_render_header()
	for i in _tab_buttons.size():
		_style_tab(_tab_buttons[i], i == _tab)
		_tab_buttons[i].text = "%s   %s%s" % [TAB_NAMES[i], _tab_count(i), ("  ●" if _tab_has_unread(i) else "")]
	_hand_toggle.text = "손글씨 보기" if print_handwriting else "정자체 보기"
	_hand_toggle.visible = _tab == Tab.RULEBOOK or _tab == Tab.REPORT
	_goals_view.visible = _tab == Tab.GOALS
	_inventory_view.visible = _tab == Tab.COLLECTION
	var is_docs := not TAB_KINDS[_tab].is_empty()
	_list_column.visible = is_docs
	_doc_view.visible = is_docs
	match _tab:
		Tab.GOALS:
			_render_goals()
			return
		Tab.COLLECTION:
			_render_inventory()
			return
	var docs := get_documents(TAB_KINDS[_tab])
	_rebuild_list(docs)
	if docs.is_empty():
		_paper.visible = false
		_prev_button.get_parent().visible = false
		_empty_label.visible = true
		_empty_label.text = "아직 받은 보고서가 없다." if _tab == Tab.REPORT else "아직 입수한 수칙서가 없다.\n가는 곳마다 안내문이 붙어 있을지도 모른다."
		return
	_empty_label.visible = false
	_paper.visible = true
	_prev_button.get_parent().visible = true
	var selected := String(_selected_doc.get(_tab, ""))
	var doc := _doc_by_id(selected)
	if doc.is_empty() or not _unlocked.has(selected):
		doc = docs[0]
		_selected_doc[_tab] = String(doc["id"])
		_rebuild_list(docs)
	_render_page(doc)


func _tab_count(tab: int) -> String:
	match tab:
		Tab.GOALS:
			return "%02d" % _objective_log().size()
		Tab.COLLECTION:
			return "%02d" % (get_documents("rulebook").size() + get_documents("report").size() + InventoryManager.items.size())
	return "%02d" % get_documents(TAB_KINDS[tab]).size()


## 머리말: 괴이저항단체 / FIELD RECORD / CHAPTER, 장소 이름 / 지금 구역
## (프로젝트 벨카의 진상이 드러나면 — VelkaStyle.VELKA_REVEAL_FLAG — 기록의 머리가 조용히 PROJECT VELKA 로 바뀐다)
func _render_header() -> void:
	var scene := get_tree().current_scene
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	_chapter_label.text = ("PROJECT VELKA" if VelkaStyle.velka_revealed() else "괴이저항단체") + " / FIELD RECORD / " + ("PROLOGUE" if chapter.begins_with("Prologue") else "CHAPTER 01" if chapter.begins_with("Chapter1") else "FIELD")
	var title := SceneManager.chapter_title(chapter) if not chapter.is_empty() else "현장"
	if title.contains("·"):
		title = title.get_slice("·", 1).strip_edges()
	_place_label.text = title
	var phase := get_tree().get_first_node_in_group("world_phase_controller")
	var zone := String(phase.get("current_zone_name")) if phase else ""
	(_place_label.get_parent().get_node("Zone") as Label).text = ("/ " + zone) if not zone.is_empty() else ""


func _rebuild_list(docs: Array) -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var selected := String(_selected_doc.get(_tab, ""))
	for doc in docs:
		var id := String(doc["id"])
		var pages := get_pages(id).size()
		var head := ("수칙서 · %d쪽" % pages) if _tab == Tab.RULEBOOK else ("MJ-%02d · 입수본" % (_docs.find(doc) + 1))
		head += "  ●" if _doc_has_unread(id) else ""
		var card := _list_card("Doc_" + id, head, String(doc["title"]), id == selected or (selected.is_empty() and doc == docs[0]), false)
		card.pressed.connect(func(): select_document(id))
		_list_box.add_child(card)
	var locked := _locked_count(TAB_KINDS[_tab])
	if locked > 0:
		var head := "입수하지 않은 기록" if _tab == Tab.RULEBOOK else "미입수"
		var title := "미발견 규칙서" if _tab == Tab.RULEBOOK else "후속 기록"
		_list_box.add_child(_list_card("Locked", head, "%s  %d" % [title, locked], false, true))


## 왼쪽 목록 카드: 작은 머리글 + 제목. 선택된 카드는 청록빛 바탕, 입수 전 카드는 흐리게.
func _list_card(card_name: String, head: String, title: String, selected: bool, locked: bool) -> Button:
	var card := Button.new()
	card.name = card_name
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 104)
	card.disabled = locked
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#1b282d") if selected else Color(0, 0, 0, 0)
	box.border_color = Color(VelkaStyle.LINE, 0.9) if selected else Color(0, 0, 0, 0)
	box.set_border_width_all(1)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#1b282d") if selected else Color(1, 1, 1, 0.04)
	for state in ["normal", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, box)
	for state in ["hover", "pressed"]:
		card.add_theme_stylebox_override(state, hover)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_right = -14
	column.offset_top = 16
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var dim := Color(VelkaStyle.INK_DIM, 0.55) if locked else VelkaStyle.INK_DIM
	column.add_child(VelkaStyle.label(head, VelkaStyle.sans(), 16, dim))
	var t := VelkaStyle.label(title, VelkaStyle.sans_semibold(), 22, Color(VelkaStyle.INK_DIM, 0.7) if locked else VelkaStyle.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(t)
	for l in column.get_children():
		(l as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _render_page(doc: Dictionary) -> void:
	var id := String(doc["id"])
	var pages := get_pages(id)
	var index := clampi(int(_page_of.get(id, 0)), 0, maxi(pages.size() - 1, 0))
	_page_of[id] = index
	var page: Dictionary = pages[index] if not pages.is_empty() else {}
	# 펼쳐 본 쪽은 '새 쪽' 표시를 지운다
	var all_pages: Array = doc.get("pages", [])
	for i in all_pages.size():
		if all_pages[i] == page:
			_unread.erase(_page_key(id, i))
	var is_rulebook := String(doc.get("kind", "")) == "rulebook"
	_doc_source.text = String(doc.get("subtitle", ""))
	_doc_title.text = String(doc["title"])
	_doc_subtitle.text = "생존자 배부용" if is_rulebook else "MJ-%02d / REV.%02d" % [_docs.find(doc) + 1, index + 1]
	_stamp.visible = not is_rulebook
	_page_title.text = String(page.get("title", ""))
	_page_title.add_theme_color_override("font_color", Color(HEAD_INK_RULEBOOK if is_rulebook else HEAD_INK_REPORT))
	# 학교 안내문 같은 '현장 문서'는 명조, 협회 내부 문서는 고딕
	var body_font := VelkaStyle.serif() if is_rulebook else VelkaStyle.sans()
	_body.add_theme_font_override("normal_font", body_font)
	_body.add_theme_font_override("bold_font", VelkaStyle.serif_bold() if is_rulebook else VelkaStyle.sans_semibold())
	var notes: Array = []
	_body.text = _page_bbcode(doc, page, notes)
	_body.scroll_to_line(0)
	_notes_head.text = "여백에 남은 필기" if is_rulebook else "필기 원문 · 작성자 구분"
	_notes.text = _notes_bbcode(notes)
	_notes.scroll_to_line(0)
	_notes_column.visible = not notes.is_empty()
	_prev_button.disabled = index <= 0
	_next_button.disabled = index >= pages.size() - 1
	_page_label.text = "%d / %d" % [index + 1, maxi(pages.size(), 1)]
	_tab_buttons[_tab].text = "%s   %s%s" % [TAB_NAMES[_tab], _tab_count(_tab), ("  ●" if _tab_has_unread(_tab) else "")]


## 본문 BBCode. 필기(여백에 남는 것)는 notes 에 모은다: [{hand, text, sign}]
func _page_bbcode(doc: Dictionary, page: Dictionary, notes: Array) -> String:
	var head_ink := HEAD_INK_RULEBOOK if String(doc.get("kind", "")) == "rulebook" else HEAD_INK_REPORT
	var out := ""
	for line in page.get("intro", []):
		out += _line_bbcode(String(line), head_ink, notes)
	if doc.has("ruleset"):
		out += _rules_bbcode(page, notes)
	else:
		for line in page.get("lines", []):
			out += _line_bbcode(String(line), head_ink, notes)
	for line in page.get("outro", []):
		out += GAP + _line_bbcode(String(line), head_ink, notes)
	return out.strip_edges(false, true)


## 줄 표기: "# 소제목", "> 인용(코멘트)", "> [소속 / 이름] 필기"(여백으로), "- 항목", "@ 라벨|내용", 빈 줄, 그 외 문단
func _line_bbcode(line: String, head_ink: String, notes: Array) -> String:
	if line.is_empty():
		return GAP
	if line.begins_with("# "):
		return "%s[b][color=%s][font_size=%d]%s[/font_size][/color][/b]\n%s" % [GAP, head_ink, BODY_SIZE + 2, _esc(line.substr(2)), GAP]
	if line.begins_with("> [") and line.find("]") > 3:
		# 대원이 남긴 필기: "> [3팀장 / 강윤] 내용" -> 여백에 손글씨로
		var close := line.find("]")
		var who := line.substr(3, close - 3).strip_edges()
		notes.append({"hand": hand_for_signer(who), "text": line.substr(close + 1).strip_edges(), "sign": signature(who)})
		return ""
	if line.begins_with("> "):
		return "[indent][color=%s][font_size=%d]%s[/font_size][/color][/indent]\n%s" % [QUOTE_INK, BODY_SIZE - 2, _esc(line.substr(2)), GAP]
	if line.begins_with("- "):
		return "[indent]•  %s[/indent]\n" % _esc(line.substr(2))
	if line.begins_with("@ "):
		var parts := line.substr(2).split("|", true, 1)
		if parts.size() == 2:
			return "[b][color=%s]%s[/color][/b]  %s\n%s" % [head_ink, _esc(parts[0]), _esc(parts[1]), GAP]
	return "%s\n%s" % [_esc(line), GAP]


## 규칙서 쪽: 구역 제목 + 번호 붙은 규칙. 알게 된 규칙에만 상태 칩을 붙이고, 메모는 여백으로 보낸다.
func _rules_bbcode(page: Dictionary, notes: Array) -> String:
	var out := ""
	var cats: Array = page.get("categories", [])
	var unnumbered: Array = page.get("unnumbered", [])
	for cat in cats:
		var rules: Array = RuleManager.get_rules_by_category(String(cat), false)
		if rules.is_empty():
			continue
		rules.sort_custom(func(a, b): return int(a["number"]) < int(b["number"]))
		# 한 쪽에 구역이 둘 이상이면 구역 제목을 따로 단다 (서문 제외)
		if cats.size() > 1 and not unnumbered.has(cat):
			out += "%s[font_size=%d][b][color=%s]%s[/color][/b][/font_size]\n%s" % [GAP, BODY_SIZE + 4, HEAD_INK_RULEBOOK, _esc(String(rules[0].get("category_name", cat))), GAP]
		for r in rules:
			var number := int(r["number"])
			var prefix := "" if unnumbered.has(cat) else "[b]%d.[/b]  " % number
			out += "%s%s\n" % [prefix, _esc(String(r["text"]))]
			if bool(r.get("discovered", false)):
				out += _rule_chips(r)
				_collect_memos(r, number if not unnumbered.has(cat) else 0, notes)
			out += GAP
	return out


## 진행 · 진위(확정 뒤에만) · 위반 결과 · 위반 횟수 칩
func _rule_chips(r: Dictionary) -> String:
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
	var association := RuleManager.status_text(id) == RuleManager.ASSOCIATION_TEXT
	if association:
		progress = RuleManager.ASSOCIATION_TEXT
	var chips: Array[String] = [_chip(progress, ASSOCIATION_INK if association else CHIP_INK)]
	if not veracity.is_empty():
		chips.append(_chip(veracity, String(VERACITY_INK.get(veracity, CHIP_INK))))
	var grade := RuleManager.grade_info(RuleManager.grade_of(id))
	chips.append(_chip("위반 결과 · " + String(grade.get("name", "?")), CHIP_INK))
	if int(r.get("strikes", 0)) > 0:
		chips.append(_chip("위반 %d회" % int(r["strikes"]), VIOLATION_INK))
	return "[indent][font=%s][font_size=%d]%s[/font_size][/font][/indent]\n" % [VelkaStyle.FONT_SANS_MEDIUM, CHIP_SIZE, "  ".join(chips)]


func _chip(text: String, ink: String) -> String:
	return "[bgcolor=%s][color=%s] %s [/color][/bgcolor]" % [CHIP_BG, ink, _esc(text)]


func _collect_memos(r: Dictionary, number: int, notes: Array) -> void:
	var tag := ("%d. " % number) if number > 0 else ""
	if r.get("memo_unlocked_sabi", false) and not String(r.get("sabi_memo", "")).is_empty():
		notes.append({"hand": HAND_SABI, "text": tag + String(r["sabi_memo"]), "sign": "— " + String(HAND_SABI["name"])})
	if r.get("memo_unlocked_shamu", false) and not String(r.get("shamu_comment", "")).is_empty():
		notes.append({"hand": HAND_SHAMU, "text": tag + String(r["shamu_comment"]), "sign": "— " + String(HAND_SHAMU["name"])})


## 여백 필기: 작성자별 글꼴·잉크 + 오른쪽 아래 서명(작은 고딕). 협회장 필기는 상자 안에. 정자체 보기면 모두 Pretendard.
func _notes_bbcode(notes: Array) -> String:
	var out := ""
	for i in notes.size():
		var note: Dictionary = notes[i]
		var hand: Dictionary = note["hand"]
		var font_path := VelkaStyle.FONT_SANS if print_handwriting else String(hand["font"])
		var size := 22 if print_handwriting else NOTE_SIZE
		var text := "[font=%s][font_size=%d][color=%s]%s[/color][/font_size][/font]" % [font_path, size, hand["ink"], _esc(String(note["text"]))]
		var sign := "[right][font=%s][font_size=15][color=#5e6870]%s[/color][/font_size][/font][/right]" % [VelkaStyle.FONT_SANS, _esc(String(note["sign"]))]
		if bool(hand.get("boxed", false)):
			out += "[table=1][cell border=#26313a66 padding=14,10,14,10]%s\n%s[/cell][/table]\n" % [text, sign]
			continue
		if i > 0:
			out += "[color=#00000033]┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄[/color]\n"
		out += text + "\n" + sign + "\n"
	return out


func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


## 목표·확인: 지금 목표 + 지나온 목표 체크 목록 + 규칙 확인 현황
func _render_goals() -> void:
	var log := _objective_log()
	_goal_now.text = String(log[-1]) if not log.is_empty() else "아직 정해진 목표가 없다."
	for child in _goal_list.get_children():
		_goal_list.remove_child(child)
		child.queue_free()
	# 진행 기록: 지금 목표(▶) 다음에 지나온 목표(✓)를 최근 것부터
	if not log.is_empty():
		_goal_list.add_child(_goal_row(String(log[-1]), true))
	for i in range(log.size() - 2, -1, -1):
		_goal_list.add_child(_goal_row(String(log[i]), false))
	_goal_list.get_parent().get_parent().get_child(_goal_list.get_parent().get_index() - 1).visible = not log.is_empty()
	var known := 0
	var verified := 0
	for r in RuleManager.get_all_rules():
		if bool(r.get("discovered", false)):
			known += 1
			if RuleManager.is_verified(String(r["id"])):
				verified += 1
	_fact_count.text = "%02d" % verified
	_fact_total.text = "/ %02d 규칙 확인" % known
	_fact_bar.max_value = maxi(known, 1)
	_fact_bar.value = verified
	for c in _fact_chips.get_children():
		_fact_chips.remove_child(c)
		c.queue_free()
	var doc_count := 0
	for doc in _docs:
		if _unlocked.has(String(doc["id"])):
			doc_count += 1
	if doc_count > 0:
		_fact_chips.add_child(_tag("문서 확보 %d" % doc_count, VelkaStyle.FOCUS))
	if known > 0:
		_fact_chips.add_child(_tag("현장 대조 중" if verified < known else "대조 완료", VelkaStyle.ACCENT))


## 목표 한 줄: 체크 상자(지금 목표 ▶ 금빛 / 지난 목표 ✓ 청록) + 글 + 아래 구분선
func _goal_row(text: String, current: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	wrap.add_child(row)
	var accent := VelkaStyle.ACCENT if current else VelkaStyle.FOCUS
	var mark := PanelContainer.new()
	var ms := VelkaStyle.panel_style(accent, Color(accent, 0.12), 0, 1)
	ms.set_content_margin_all(0)
	mark.add_theme_stylebox_override("panel", ms)
	mark.custom_minimum_size = Vector2(26, 26)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glyph := VelkaStyle.label("▶" if current else "✓", VelkaStyle.sans(), 14 if current else 17, accent)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(glyph)
	row.add_child(mark)
	var l := VelkaStyle.label(text, VelkaStyle.sans_semibold(), 24, VelkaStyle.ACCENT if current else Color(VelkaStyle.INK, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	wrap.add_child(_rule_line())
	return wrap


## 작은 테두리 칩 (확인한 사실 칸)
func _tag(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var cs := VelkaStyle.panel_style(Color(color, 0.7), Color(color, 0.08), 0, 1)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 3
	cs.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", cs)
	chip.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, color))
	return chip


## 수집 기록 (시안 07): 입수한 문서 카드 + 미발견 카드, 그 아래 소지품 카드
func _render_inventory() -> void:
	for child in _inventory_box.get_children():
		_inventory_box.remove_child(child)
		child.queue_free()
	# 입수한 자료
	var docs: Array = []
	var locked := 0
	for doc in _docs:
		if _unlocked.has(String(doc["id"])):
			docs.append(doc)
		else:
			locked += 1
	_inventory_box.add_child(_section_head("입수한 자료", docs.size()))
	var grid := _card_grid()
	_inventory_box.add_child(grid)
	for doc in docs:
		var id := String(doc["id"])
		var kind := String(doc.get("kind", ""))
		var card := _collection_card("Doc_" + id, "규칙서" if kind == "rulebook" else "협회 자료", String(doc["title"]),
				"%s\n열람할 수 있는 쪽 %d" % [String(doc.get("subtitle", "")), get_pages(id).size()], true)
		card.pressed.connect(func(): _open_document(id))
		grid.add_child(card)
	if locked > 0:
		grid.add_child(_locked_card(locked))
	if docs.is_empty() and locked == 0:
		_inventory_box.add_child(VelkaStyle.label("아직 입수한 자료가 없다.", VelkaStyle.sans(), 22, VelkaStyle.INK_DIM))

	# 소지품
	var items: Array = InventoryManager.items
	_inventory_box.add_child(_spacer(10))
	var head := _section_head("소지품", items.size())
	head.add_child(VelkaStyle.label("손전등 배터리  %d%%" % roundi(InventoryManager.battery_level / maxf(InventoryManager.max_battery, 1.0) * 100.0),
			VelkaStyle.sans(), 18, VelkaStyle.INK_DIM))
	_inventory_box.add_child(head)
	if items.is_empty():
		var empty := VelkaStyle.label("가진 물건이 없다.", VelkaStyle.sans(), 22, VelkaStyle.INK_DIM)
		empty.name = "EmptyInventory"
		_inventory_box.add_child(empty)
		return
	var item_grid := _card_grid()
	_inventory_box.add_child(item_grid)
	for item in items:
		var name_text := String(item)
		var desc := String(_item_info.get(name_text, {}).get("description", ""))
		var card := _collection_card("Item_" + name_text, "소지품", name_text, desc, false)
		item_grid.add_child(card)


## 문서 카드를 누르면 그 문서가 있는 탭에서 연다
func _open_document(document_id: String) -> void:
	var doc := _doc_by_id(document_id)
	show_tab(Tab.RULEBOOK if String(doc.get("kind", "")) == "rulebook" else Tab.REPORT)
	select_document(document_id)


func _section_head(title: String, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(VelkaStyle.label("%s  %02d" % [title, count], VelkaStyle.spaced(VelkaStyle.sans_semibold(), 2), 18, VelkaStyle.ACCENT))
	return row


func _card_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


## 자료 카드: 종류 칩 + 제목 + 설명
func _collection_card(card_name: String, kind: String, title: String, desc: String, clickable: bool) -> Button:
	var card := Button.new()
	card.name = card_name
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 200)
	var box := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#16242a"), 0, 1)
	var hover := VelkaStyle.panel_style(VelkaStyle.FOCUS, Color("#1b2d33"), 0, 1)
	for state in ["normal", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, box)
	for state in ["hover", "pressed"]:
		card.add_theme_stylebox_override(state, hover if clickable else box)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 24
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var chip := PanelContainer.new()
	var cs := VelkaStyle.panel_style(Color(VelkaStyle.FOCUS, 0.6) if kind != "소지품" else Color(VelkaStyle.ACCENT, 0.6), Color(0, 0, 0, 0.2), 0, 1)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 2
	cs.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", cs)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_child(VelkaStyle.label(kind, VelkaStyle.sans(), 15, VelkaStyle.INK))
	column.add_child(chip)
	var t := VelkaStyle.label(title, VelkaStyle.sans_bold(), 24, VelkaStyle.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(t)
	if not desc.strip_edges().is_empty():
		var d := VelkaStyle.label(desc.strip_edges(), VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(d)
	for c in column.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## 미발견 카드 (점선 테두리)
func _locked_card(count: int) -> Control:
	var card := DashedPanel.new()
	card.name = "LockedDocs"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 200)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 26
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(VelkaStyle.label("미발견  %d" % count, VelkaStyle.sans(), 16, VelkaStyle.INK_DIM))
	column.add_child(VelkaStyle.label("아직 확보하지 않은 자료", VelkaStyle.sans_medium(), 23, Color(VelkaStyle.INK_DIM, 0.85)))
	column.add_child(VelkaStyle.label("내용을 확인할 수 없습니다.", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM))
	return card


func _scroll_body(amount: float) -> void:
	if _body == null or not _body.is_visible_in_tree():
		return
	var bar := _body.get_v_scroll_bar()
	bar.value = clampf(bar.value + amount, 0.0, maxf(bar.max_value - bar.page, 0.0))


# --- UI 만들기 ----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "JournalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.04, 0.05, 0.82)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "JournalPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 75
	panel.offset_right = -75
	panel.offset_top = 55
	panel.offset_bottom = -45
	var panel_style := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#0f151a"), 0, 1)
	panel_style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	panel.add_child(page)
	page.add_child(_build_header())
	page.add_child(_rule_line())
	page.add_child(_build_tab_bar())
	page.add_child(_rule_line())

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	page.add_child(content)
	content.add_child(_build_list_column())
	content.add_child(_build_doc_view())
	content.add_child(_build_goals_view())
	content.add_child(_build_inventory_view())

	page.add_child(_rule_line())
	page.add_child(_build_footer())


func _rule_line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _build_header() -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 46)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_chapter_label = VelkaStyle.label("FIELD RECORD", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 15, VelkaStyle.INK_DIM)
	column.add_child(_chapter_label)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	column.add_child(title_row)
	_place_label = VelkaStyle.label("", VelkaStyle.sans_bold(), 38, VelkaStyle.INK)
	title_row.add_child(_place_label)
	var zone := VelkaStyle.label("", VelkaStyle.sans_semibold(), 20, VelkaStyle.INK_DIM)
	zone.name = "Zone"
	zone.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(zone)
	var close_row := HBoxContainer.new()
	close_row.add_theme_constant_override("separation", 10)
	close_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_row.add_child(_keycap("Tab"))
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.text = "기록 닫기"
	close_button.flat = true
	close_button.add_theme_font_override("font", VelkaStyle.sans())
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.add_theme_color_override("font_color", VelkaStyle.INK)
	close_button.pressed.connect(close)
	close_row.add_child(close_button)
	row.add_child(close_row)
	return margin


func _build_tab_bar() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 46)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	margin.add_child(bar)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.name = "Tab_%d" % i
		button.focus_mode = Control.FOCUS_NONE
		button.text = TAB_NAMES[i]
		button.custom_minimum_size = Vector2(210, 68)
		var tab := i
		button.pressed.connect(func(): show_tab(tab))
		bar.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_hand_toggle = Button.new()
	_hand_toggle.name = "HandwritingToggle"
	_hand_toggle.focus_mode = Control.FOCUS_NONE
	_hand_toggle.flat = true
	_hand_toggle.add_theme_font_override("font", VelkaStyle.sans())
	_hand_toggle.add_theme_font_size_override("font_size", 18)
	_hand_toggle.add_theme_color_override("font_color", VelkaStyle.INK)
	_hand_toggle.pressed.connect(func(): set_print_handwriting(not print_handwriting))
	bar.add_child(_hand_toggle)
	return margin


func _style_tab(button: Button, selected: bool) -> void:
	button.add_theme_font_override("font", VelkaStyle.sans_medium())
	button.add_theme_font_size_override("font_size", 22)
	var ink := VelkaStyle.INK if selected else Color(VelkaStyle.INK, 0.72)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", VelkaStyle.INK)
	button.add_theme_color_override("font_pressed_color", VelkaStyle.INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.03) if selected else Color(0, 0, 0, 0)
	normal.border_color = VelkaStyle.FOCUS if selected else Color(0, 0, 0, 0)
	normal.border_width_bottom = 3
	normal.content_margin_left = 26
	normal.content_margin_right = 26
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.05)
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, hover)


func _build_list_column() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(310, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(VelkaStyle.LINE, 0.7)
	style.border_width_right = 1
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 28
	frame.add_theme_stylebox_override("panel", style)
	_list_column = frame
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 18)
	frame.add_child(_list_box)
	return _list_column


func _build_doc_view() -> Control:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 18)
	_doc_view = margin
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_paper = PanelContainer.new()
	_paper.name = "Paper"
	_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper_style := VelkaStyle.panel_style(Color("#c9c0aa"), VelkaStyle.PAPER, 0, 1)
	paper_style.content_margin_left = 40
	paper_style.content_margin_right = 40
	paper_style.content_margin_top = 30
	paper_style.content_margin_bottom = 26
	paper_style.shadow_color = Color(0, 0, 0, 0.45)
	paper_style.shadow_size = 12
	_paper.add_theme_stylebox_override("panel", paper_style)
	column.add_child(_paper)

	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 10)
	_paper.add_child(sheet)
	# 문서 머리: 출처(왼쪽) · 문서 번호(오른쪽) · 내부 열람 도장
	var head := HBoxContainer.new()
	sheet.add_child(head)
	_doc_source = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans_medium(), 2), 16, Color("#4b5560"))
	_doc_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_doc_source)
	_doc_subtitle = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans_medium(), 2), 16, Color("#4b5560"))
	head.add_child(_doc_subtitle)
	_stamp = VelkaStyle.label("내부 열람", VelkaStyle.spaced(VelkaStyle.sans_semibold(), 4), 17, Color("#8b3a2e"))
	var stamp_box := StyleBoxFlat.new()
	stamp_box.bg_color = Color(0, 0, 0, 0)
	stamp_box.border_color = Color("#8b3a2e")
	stamp_box.set_border_width_all(2)
	stamp_box.content_margin_left = 10
	stamp_box.content_margin_right = 10
	stamp_box.content_margin_top = 2
	stamp_box.content_margin_bottom = 2
	_stamp.add_theme_stylebox_override("normal", stamp_box)
	_stamp.rotation_degrees = -4.0
	head.add_child(_stamp)
	var rule := ColorRect.new()
	rule.color = Color("#26313a", 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	sheet.add_child(rule)
	_doc_title = VelkaStyle.label("", VelkaStyle.sans_bold(), 30, VelkaStyle.PAPER_INK)
	_doc_title.name = "DocTitle"
	sheet.add_child(_doc_title)
	_page_title = VelkaStyle.label("", VelkaStyle.sans_semibold(), 22, Color(HEAD_INK_RULEBOOK))
	_page_title.name = "PageTitle"
	_page_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_page_title)

	# 본문(왼쪽) | 여백 필기(오른쪽)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 28)
	sheet.add_child(split)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.scroll_active = true
	_body.selection_enabled = false
	_body.focus_mode = Control.FOCUS_NONE
	_body.add_theme_font_override("normal_font", VelkaStyle.serif())
	_body.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	_body.add_theme_font_override("mono_font", VelkaStyle.mono())
	_body.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	_body.add_theme_font_size_override("bold_font_size", BODY_SIZE)
	_body.add_theme_color_override("default_color", VelkaStyle.PAPER_INK)
	_body.add_theme_constant_override("line_separation", 9)
	split.add_child(_body)
	_slim_scrollbar(_body)

	var notes_frame := PanelContainer.new()
	notes_frame.custom_minimum_size = Vector2(430, 0)
	var notes_style := StyleBoxFlat.new()
	notes_style.bg_color = Color(0, 0, 0, 0)
	notes_style.border_color = Color("#26313a", 0.25)
	notes_style.border_width_left = 1
	notes_style.content_margin_left = 26
	notes_frame.add_theme_stylebox_override("panel", notes_style)
	split.add_child(notes_frame)
	_notes_column = notes_frame
	var notes_box := VBoxContainer.new()
	notes_box.add_theme_constant_override("separation", 8)
	notes_frame.add_child(notes_box)
	_notes_head = VelkaStyle.label("여백에 남은 필기", VelkaStyle.sans(), 15, Color("#5e6870"))
	notes_box.add_child(_notes_head)
	_notes = RichTextLabel.new()
	_notes.name = "Notes"
	_notes.bbcode_enabled = true
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.scroll_active = true
	_notes.selection_enabled = false
	_notes.focus_mode = Control.FOCUS_NONE
	_notes.add_theme_constant_override("line_separation", 4)
	_notes.add_theme_color_override("default_color", VelkaStyle.PAPER_INK)
	notes_box.add_child(_notes)
	_slim_scrollbar(_notes)
	var disclaimer := VelkaStyle.label("필기는 참고 자료이며, 내용의 정확성을 보장하지 않습니다.", VelkaStyle.sans(), 14, Color("#5e6870"))
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes_box.add_child(disclaimer)

	_empty_label = VelkaStyle.label("", VelkaStyle.sans(), 26, VelkaStyle.INK_DIM)
	_empty_label.name = "EmptyLabel"
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	column.add_child(_empty_label)

	var footer := HBoxContainer.new()
	footer.name = "PageNav"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	column.add_child(footer)
	_prev_button = Button.new()
	_prev_button.name = "PrevPage"
	_prev_button.text = "◀  이전 쪽"
	_prev_button.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(_prev_button, VelkaStyle.INK)
	_prev_button.pressed.connect(func(): turn_page(-1))
	footer.add_child(_prev_button)
	_page_label = VelkaStyle.label("1 / 1", VelkaStyle.sans_medium(), 19, VelkaStyle.INK)
	_page_label.custom_minimum_size = Vector2(110, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_page_label)
	_next_button = Button.new()
	_next_button.name = "NextPage"
	_next_button.text = "다음 쪽  ▶"
	_next_button.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(_next_button, VelkaStyle.INK)
	_next_button.pressed.connect(func(): turn_page(1))
	footer.add_child(_next_button)
	return _doc_view


## 목표·확인: 가운데 지금 목표와 체크 목록, 오른쪽 '확인한 사실'
func _build_goals_view() -> Control:
	var margin := MarginContainer.new()
	margin.name = "GoalsView"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 36)
	margin.visible = false
	_goals_view = margin
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	row.add_child(main)
	main.add_child(VelkaStyle.label("현재 목표", VelkaStyle.spaced(VelkaStyle.sans_semibold(), 4), 18, VelkaStyle.ACCENT))
	_goal_now = VelkaStyle.label("", VelkaStyle.sans_bold(), 34, VelkaStyle.INK)
	_goal_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_goal_now)
	main.add_child(_spacer(18))
	main.add_child(VelkaStyle.label("진행 기록", VelkaStyle.spaced(VelkaStyle.sans_medium(), 3), 17, VelkaStyle.INK_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	_goal_list = VBoxContainer.new()
	_goal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_goal_list)

	var side_frame := PanelContainer.new()
	side_frame.custom_minimum_size = Vector2(380, 0)
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color(0, 0, 0, 0)
	side_style.border_color = Color(VelkaStyle.LINE, 0.7)
	side_style.border_width_left = 1
	side_style.content_margin_left = 30
	side_frame.add_theme_stylebox_override("panel", side_style)
	row.add_child(side_frame)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side_frame.add_child(side)
	side.add_child(VelkaStyle.label("확인한 사실", VelkaStyle.sans_semibold(), 22, VelkaStyle.INK))
	_fact_chips = HBoxContainer.new()
	_fact_chips.add_theme_constant_override("separation", 8)
	side.add_child(_fact_chips)
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 12)
	side.add_child(count_row)
	_fact_count = VelkaStyle.label("00", VelkaStyle.sans_medium(), 60, VelkaStyle.ACCENT)
	count_row.add_child(_fact_count)
	_fact_total = VelkaStyle.label("/ 00 규칙 확인", VelkaStyle.sans_medium(), 22, VelkaStyle.INK_DIM)
	_fact_total.size_flags_vertical = Control.SIZE_SHRINK_END
	count_row.add_child(_fact_total)
	_fact_bar = ProgressBar.new()
	_fact_bar.show_percentage = false
	_fact_bar.custom_minimum_size = Vector2(0, 4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(VelkaStyle.LINE, 0.6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = VelkaStyle.ACCENT
	_fact_bar.add_theme_stylebox_override("background", bg)
	_fact_bar.add_theme_stylebox_override("fill", fill)
	side.add_child(_fact_bar)
	var note := VelkaStyle.label("알게 된 규칙 가운데 직접 확인해 확정한 수입니다.\n목표와 규칙의 확인 상태는 각각 기록됩니다.", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(note)
	return _goals_view


func _build_inventory_view() -> Control:
	_inventory_view = ScrollContainer.new()
	_inventory_view.name = "InventoryView"
	_inventory_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_view.visible = false
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	_inventory_view.add_child(margin)
	_inventory_box = VBoxContainer.new()
	_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_box.add_theme_constant_override("separation", 18)
	margin.add_child(_inventory_box)
	return _inventory_view


## 아래 띠: 안내 문구 + 조작 키
func _build_footer() -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var info := VelkaStyle.label("입수한 기록만 열람할 수 있습니다.", VelkaStyle.sans(), 18, VelkaStyle.INK)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	for pair in [["1–4", "탭 전환"], ["← →", "쪽"], ["↑ ↓", "문서"], ["Esc", "닫기"]]:
		row.add_child(_keycap(pair[0]))
		var l := VelkaStyle.label(pair[1], VelkaStyle.sans(), 18, VelkaStyle.INK)
		l.custom_minimum_size.x = 64
		row.add_child(l)
	return margin


static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := VelkaStyle.panel_style(Color(VelkaStyle.INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.content_margin_left = 8
	box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, VelkaStyle.INK))
	return cap


## 종이 위의 얇은 스크롤 막대
func _slim_scrollbar(text: RichTextLabel) -> void:
	var bar := text.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#26313a", 0.08)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("#26313a", 0.35)
	grab.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.custom_minimum_size.x = 6


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## 점선 테두리 상자 (수집 기록의 미발견 카드)
class DashedPanel extends Control:
	func _draw() -> void:
		var c := Color(VelkaStyle.LINE, 0.9)
		var dash := 6.0
		var gap := 4.0
		var corners := [Vector2(0.5, 0.5), Vector2(size.x - 0.5, 0.5), Vector2(size.x - 0.5, size.y - 0.5), Vector2(0.5, size.y - 0.5)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var length := a.distance_to(b)
			var dir := (b - a) / maxf(length, 0.001)
			var t := 0.0
			while t < length:
				draw_line(a + dir * t, a + dir * minf(t + dash, length), c, 1.0)
				t += dash + gap
