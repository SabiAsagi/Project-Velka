extends CanvasLayer

# 프로젝트 벨카 - 수첩 (Tab)
# 탭 3개: 협회 보고서 / 수칙서 / 인벤토리. R(옛 규칙 수첩 키)은 수칙서 탭을 바로 연다.
#   - 보고서·수칙서는 문서 목록(왼쪽) + 쪽(오른쪽)으로 보인다. 문서와 쪽은 data/journal/documents.json 에 있고,
#     story flag(unlock_flag)나 규칙 발견(unlock_category / categories)으로 열린다. 새로 열리면 HUD에 알린다.
#   - 규칙서 문서(ruleset)는 본문을 RuleManager 규칙 데이터에서 그린다. 이미 알게 된 규칙에만 상태 표시와 사비/샤무 메모가 붙는다.
#   - 인벤토리는 InventoryManager.items 목록 (설명은 data/journal/items.json).
# 열려 있는 동안에는 탐색 입력이 잠긴다. 키: Tab / Esc 닫기, Q E 또는 1 2 3 탭, ← → (A D) 쪽, ↑ ↓ 문서, 휠 · W S 스크롤.

signal opened()
signal closed()
## 수첩에 새 문서/쪽이 열렸을 때 (page_title이 비어 있으면 문서 전체)
signal page_unlocked(document_id: String, page_title: String)

enum Tab { REPORT, RULEBOOK, INVENTORY }

const LOCK_REASON := "journal"
const DOCUMENTS_PATH := "res://data/journal/documents.json"
const ITEMS_PATH := "res://data/journal/items.json"
const TAB_NAMES: Array[String] = ["협회 보고서", "수칙서", "인벤토리"]
const TAB_KINDS: Array[String] = ["report", "rulebook", ""]
const NOTICE_COLOR := Color(0.95, 0.85, 0.55)

const BODY_SIZE := 25
const NOTE_SIZE := 17
const MEMO_SIZE := 20
const PAPER_RULEBOOK := Color(0.94, 0.9, 0.8)
const PAPER_REPORT := Color(0.89, 0.9, 0.9)
const HEAD_INK := "#6e1d18"
const QUOTE_INK := "#4b4338"
const STATUS_INK := {0: "#585858", 1: "#23683a", 2: "#85660b", 3: "#a3261c", 4: "#65399c"}
const ASSOCIATION_INK := "#26597a"
const SABI_INK := "#17535d"
const SHAMU_INK := "#76540a"
const VIOLATION_INK := "#8e2b1f"
## 문단 사이의 좁은 빈 줄 (빈 줄 하나를 통째로 넣으면 너무 벌어진다)
const GAP := "[font_size=10] [/font_size]\n"

var _docs: Array = []
var _item_info: Dictionary = {}
var _tab: int = Tab.REPORT
var _selected_doc: Dictionary = {}   # 탭 -> 선택한 문서 id
var _page_of: Dictionary = {}        # 문서 id -> 열람 가능한 쪽 목록에서의 위치
var _unlocked: Dictionary = {}       # 열려 있는 문서("doc") / 쪽("doc:index") 키
var _unread: Dictionary = {}         # 아직 펼쳐 보지 않은 새 쪽 키
var _pending_notices: Array[String] = []

var _root: Control
var _tab_buttons: Array[Button] = []
var _list_column: Control
var _list_box: VBoxContainer
var _doc_view: Control
var _paper: PanelContainer
var _doc_title: Label
var _doc_subtitle: Label
var _page_title: Label
var _body: RichTextLabel
var _empty_label: Label
var _prev_button: Button
var _next_button: Button
var _page_label: Label
var _inventory_view: ScrollContainer
var _inventory_box: VBoxContainer


func _ready() -> void:
	layer = 40
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
		KEY_1, KEY_2, KEY_3:
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


## 문서를 펼친다. 현재 탭에 없는 문서면 false
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
	if _tab == Tab.INVENTORY:
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
	if _tab == Tab.INVENTORY:
		return
	var id := get_current_document_id()
	if id.is_empty():
		return
	var count := get_pages(id).size()
	_page_of[id] = clampi(int(_page_of.get(id, 0)) + delta, 0, maxi(count - 1, 0))
	_render()


## 지금 쪽의 BBCode 본문 (테스트·점검용)
func get_page_text() -> String:
	return _body.text if _body else ""


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
	if tab == Tab.INVENTORY:
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


# --- 그리기 -----------------------------------------------------------------

func _render() -> void:
	for i in _tab_buttons.size():
		_style_tab(_tab_buttons[i], i == _tab)
		_tab_buttons[i].text = TAB_NAMES[i] + ("  ●" if _tab_has_unread(i) else "")
	var is_inventory := _tab == Tab.INVENTORY
	_inventory_view.visible = is_inventory
	_list_column.visible = not is_inventory
	_doc_view.visible = not is_inventory
	if is_inventory:
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


func _rebuild_list(docs: Array) -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var selected := String(_selected_doc.get(_tab, ""))
	for doc in docs:
		var id := String(doc["id"])
		var button := Button.new()
		button.name = "Doc_" + id
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = String(doc["title"]) + ("  ●" if _doc_has_unread(id) else "")
		VelkaStyle.style_button(button, VelkaStyle.RED_SOFT, 23)
		if id == selected or (selected.is_empty() and doc == docs[0]):
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
			button.add_theme_color_override("font_color", VelkaStyle.INK)
		button.pressed.connect(func(): select_document(id))
		_list_box.add_child(button)


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
	var paper_style := _paper.get_theme_stylebox("panel") as StyleBoxFlat
	paper_style.bg_color = PAPER_RULEBOOK if is_rulebook else PAPER_REPORT
	_doc_title.text = String(doc["title"])
	_doc_subtitle.text = String(doc.get("subtitle", ""))
	_doc_subtitle.visible = not _doc_subtitle.text.is_empty()
	_page_title.text = String(page.get("title", ""))
	_body.text = _page_bbcode(doc, page)
	_body.scroll_to_line(0)
	_prev_button.disabled = index <= 0
	_next_button.disabled = index >= pages.size() - 1
	_page_label.text = "%d / %d" % [index + 1, maxi(pages.size(), 1)]
	_tab_buttons[_tab].text = TAB_NAMES[_tab] + ("  ●" if _tab_has_unread(_tab) else "")


func _page_bbcode(doc: Dictionary, page: Dictionary) -> String:
	var out := ""
	for line in page.get("intro", []):
		out += _line_bbcode(String(line))
	if doc.has("ruleset"):
		out += _rules_bbcode(page)
	else:
		for line in page.get("lines", []):
			out += _line_bbcode(String(line))
	for line in page.get("outro", []):
		out += GAP + _line_bbcode(String(line))
	return out.strip_edges(false, true)


## 줄 표기: "# 소제목", "> 인용(코멘트)", "- 항목", "@ 라벨|내용", 빈 줄, 그 외 문단
func _line_bbcode(line: String) -> String:
	if line.is_empty():
		return GAP
	if line.begins_with("# "):
		return "%s[b][color=%s]%s[/color][/b]\n%s" % [GAP, HEAD_INK, _esc(line.substr(2)), GAP]
	if line.begins_with("> "):
		return "[indent][color=%s][font_size=%d]%s[/font_size][/color][/indent]\n%s" % [QUOTE_INK, BODY_SIZE - 2, _esc(line.substr(2)), GAP]
	if line.begins_with("- "):
		return "[indent]•  %s[/indent]\n" % _esc(line.substr(2))
	if line.begins_with("@ "):
		var parts := line.substr(2).split("|", true, 1)
		if parts.size() == 2:
			return "[b][color=%s]%s[/color][/b]  %s\n%s" % [HEAD_INK, _esc(parts[0]), _esc(parts[1]), GAP]
	return "%s\n%s" % [_esc(line), GAP]


## 규칙서 쪽: 구역 제목 + 번호 붙은 규칙. 알게 된 규칙에만 상태 표시와 메모를 붙인다.
func _rules_bbcode(page: Dictionary) -> String:
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
			out += "%s[font_size=%d][b][color=%s]%s[/color][/b][/font_size]\n%s" % [GAP, BODY_SIZE + 5, HEAD_INK, _esc(String(rules[0].get("category_name", cat))), GAP]
		for r in rules:
			var prefix := "" if unnumbered.has(cat) else "[b]%d.[/b]  " % int(r["number"])
			out += "%s%s\n" % [prefix, _esc(String(r["text"]))]
			if bool(r.get("discovered", false)):
				out += _rule_note_bbcode(r)
			out += GAP
	return out


## 알게 된 규칙 아래에 작게: [상태]  위반 결과  위반 횟수 / 사비 메모 / 샤무 코멘트
func _rule_note_bbcode(r: Dictionary) -> String:
	var id := String(r["id"])
	var status := int(r.get("status", 0))
	var label := RuleManager.status_text(id)
	var ink: String = ASSOCIATION_INK if label == RuleManager.ASSOCIATION_TEXT else String(STATUS_INK.get(status, "#585858"))
	var grade := RuleManager.grade_info(RuleManager.grade_of(id))
	var note := "[indent][code][font_size=%d][color=%s]■ %s[/color]" % [NOTE_SIZE, ink, _esc(label)]
	note += "  [color=%s]위반 결과 %s[/color]" % [QUOTE_INK, _esc(String(grade.get("name", "?")))]
	if int(r.get("strikes", 0)) > 0:
		note += "  [color=%s]위반 %d회[/color]" % [VIOLATION_INK, int(r["strikes"])]
	note += "[/font_size][/code]\n"
	if r.get("memo_unlocked_sabi", false) and not String(r.get("sabi_memo", "")).is_empty():
		note += "[font_size=%d][color=%s][b]사비 메모[/b]  %s[/color][/font_size]\n" % [MEMO_SIZE, SABI_INK, _esc(String(r["sabi_memo"]))]
	if r.get("memo_unlocked_shamu", false) and not String(r.get("shamu_comment", "")).is_empty():
		note += "[font_size=%d][color=%s][b]샤무[/b]  %s[/color][/font_size]\n" % [MEMO_SIZE, SHAMU_INK, _esc(String(r["shamu_comment"]))]
	return note + "[/indent]"


func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


func _render_inventory() -> void:
	for child in _inventory_box.get_children():
		_inventory_box.remove_child(child)
		child.queue_free()
	var items: Array = InventoryManager.items
	_inventory_box.add_child(VelkaStyle.label("소지품  %d" % items.size(), VelkaStyle.mono(), 18, VelkaStyle.INK_DIM))
	var battery := VelkaStyle.label("손전등 배터리   %d%%" % roundi(InventoryManager.battery_level / maxf(InventoryManager.max_battery, 1.0) * 100.0),
			VelkaStyle.serif(), 24, VelkaStyle.INK)
	_inventory_box.add_child(battery)
	if items.is_empty():
		var empty := VelkaStyle.label("가진 물건이 없다.", VelkaStyle.serif(), 26, VelkaStyle.INK_DIM)
		empty.name = "EmptyInventory"
		_inventory_box.add_child(empty)
		return
	for item in items:
		var name_text := String(item)
		var row := PanelContainer.new()
		row.name = "Item_" + name_text
		row.add_theme_stylebox_override("panel", VelkaStyle.panel_style(VelkaStyle.LINE, VelkaStyle.BG_SOFT, 4))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		row.add_child(box)
		box.add_child(VelkaStyle.label(name_text, VelkaStyle.serif_bold(), 28, VelkaStyle.INK))
		var desc := String(_item_info.get(name_text, {}).get("description", ""))
		if not desc.is_empty():
			var d := VelkaStyle.label(desc, VelkaStyle.serif(), 22, VelkaStyle.INK_DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(d)
		_inventory_box.add_child(row)


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
	dimmer.color = Color(0, 0, 0, 0.74)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "JournalPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 90
	panel.offset_right = -90
	panel.offset_top = 44
	panel.offset_bottom = -44
	var panel_style := VelkaStyle.panel_style(VelkaStyle.LINE, Color(0.05, 0.06, 0.08, 0.98), 6, 2)
	panel_style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	panel.add_child(page)

	page.add_child(_build_tab_bar())
	var line := ColorRect.new()
	line.color = VelkaStyle.LINE
	line.custom_minimum_size = Vector2(0, 2)
	page.add_child(line)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 28)
	page.add_child(content)
	content.add_child(_build_list_column())
	content.add_child(_build_doc_view())
	content.add_child(_build_inventory_view())


func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.name = "Tab_%d" % i
		button.focus_mode = Control.FOCUS_NONE
		button.text = TAB_NAMES[i]
		var tab := i
		button.pressed.connect(func(): show_tab(tab))
		bar.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var hint := VelkaStyle.label("Q E 탭   ← → 쪽   ↑ ↓ 문서   휠 W S 스크롤   Tab · Esc 닫기", VelkaStyle.mono(), 17, VelkaStyle.INK_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.text = "닫기"
	VelkaStyle.style_small_button(close_button, VelkaStyle.INK_DIM)
	close_button.pressed.connect(close)
	bar.add_child(close_button)
	return bar


func _style_tab(button: Button, selected: bool) -> void:
	button.add_theme_font_override("font", VelkaStyle.serif_bold())
	button.add_theme_font_size_override("font_size", 28)
	var ink := VelkaStyle.INK if selected else VelkaStyle.INK_DIM
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", VelkaStyle.INK)
	button.add_theme_color_override("font_pressed_color", VelkaStyle.INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.07) if selected else Color(0, 0, 0, 0)
	normal.border_color = VelkaStyle.RED_SOFT if selected else Color(0, 0, 0, 0)
	normal.border_width_bottom = 4
	normal.content_margin_left = 26
	normal.content_margin_right = 26
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.1)
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, hover)


func _build_list_column() -> Control:
	_list_column = VBoxContainer.new()
	_list_column.custom_minimum_size = Vector2(340, 0)
	_list_column.add_theme_constant_override("separation", 10)
	_list_column.add_child(VelkaStyle.label("문서", VelkaStyle.mono(), 17, VelkaStyle.INK_DIM))
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_column.add_child(_list_box)
	return _list_column


func _build_doc_view() -> Control:
	_doc_view = VBoxContainer.new()
	_doc_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doc_view.add_theme_constant_override("separation", 12)

	_paper = PanelContainer.new()
	_paper.name = "Paper"
	_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper_style := VelkaStyle.panel_style(Color(0.45, 0.4, 0.32), PAPER_RULEBOOK, 3, 2)
	paper_style.content_margin_left = 64
	paper_style.content_margin_right = 52
	paper_style.content_margin_top = 34
	paper_style.content_margin_bottom = 30
	paper_style.shadow_color = Color(0, 0, 0, 0.5)
	paper_style.shadow_size = 14
	_paper.add_theme_stylebox_override("panel", paper_style)
	_doc_view.add_child(_paper)

	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 8)
	_paper.add_child(sheet)
	_doc_title = VelkaStyle.label("", VelkaStyle.serif_bold(), 38, VelkaStyle.PAPER_INK)
	_doc_title.name = "DocTitle"
	sheet.add_child(_doc_title)
	_doc_subtitle = VelkaStyle.label("", VelkaStyle.mono(), 17, Color(0.38, 0.35, 0.3))
	sheet.add_child(_doc_subtitle)
	var rule := ColorRect.new()
	rule.color = Color(0.16, 0.14, 0.12, 0.75)
	rule.custom_minimum_size = Vector2(0, 3)
	sheet.add_child(rule)
	_page_title = VelkaStyle.label("", VelkaStyle.serif_bold(), 31, Color(0.43, 0.11, 0.09))
	_page_title.name = "PageTitle"
	_page_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_page_title)

	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.scroll_active = true
	_body.selection_enabled = false
	_body.focus_mode = Control.FOCUS_NONE
	_body.add_theme_font_override("normal_font", VelkaStyle.serif())
	_body.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	_body.add_theme_font_override("mono_font", VelkaStyle.mono())
	_body.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	_body.add_theme_font_size_override("bold_font_size", BODY_SIZE)
	_body.add_theme_font_size_override("mono_font_size", NOTE_SIZE)
	_body.add_theme_color_override("default_color", VelkaStyle.PAPER_INK)
	_body.add_theme_constant_override("line_separation", 10)
	sheet.add_child(_body)

	_empty_label = VelkaStyle.label("", VelkaStyle.serif(), 28, VelkaStyle.INK_DIM)
	_empty_label.name = "EmptyLabel"
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	_doc_view.add_child(_empty_label)

	var footer := HBoxContainer.new()
	footer.name = "PageNav"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	_doc_view.add_child(footer)
	_prev_button = Button.new()
	_prev_button.name = "PrevPage"
	_prev_button.text = "◀  이전 쪽"
	_prev_button.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(_prev_button, VelkaStyle.INK)
	_prev_button.pressed.connect(func(): turn_page(-1))
	footer.add_child(_prev_button)
	_page_label = VelkaStyle.label("1 / 1", VelkaStyle.mono(), 20, VelkaStyle.INK)
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


func _build_inventory_view() -> Control:
	_inventory_view = ScrollContainer.new()
	_inventory_view.name = "InventoryView"
	_inventory_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_view.visible = false
	_inventory_box = VBoxContainer.new()
	_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_box.add_theme_constant_override("separation", 12)
	_inventory_view.add_child(_inventory_box)
	return _inventory_view
