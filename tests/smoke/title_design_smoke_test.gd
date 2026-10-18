extends SceneTree

# 프로젝트 벨카 - 타이틀 화면 = 피그마 시안 그대로 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/title_design_smoke_test.gd
#   1. 옛 타이틀 요소(문구 · 표어 · 조작 안내 · 청록 V 표시)는 없다
#   2. 시안 BrandMark 로고 두 층, 시안 좌표의 메뉴 (나눔명조 줄 메뉴, 기록 보관소는 새 게임 아래)
#   3. 저장이 없으면 이어하기는 먹줄 + "저장 기록 없음", 새 게임 옆엔 "프롤로그"
#   4. 처음엔 선택 표시가 숨고, 키를 누르면 핏빛 선택 표시가 켜진다 (:focus-visible)
#   5. 처음 켤 때만 부팅 연출, '벨카' 글리치, '화면 효과 줄이기'면 움직임을 끈다

const TITLE := "res://scenes/ui/TitleScreen.tscn"
const ORDER := ["이어하기", "불러오기", "새 게임", "기록 보관소", "환경 설정", "제작진", "종료"]

var _started := false
var _passes := 0
var _failures: Array[String] = []
var _save_backup = null
var _save_path := ""


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var settings := root.get_node("/root/SettingsManager")
	var calm_before: bool = settings.current_settings["accessibility"]["reduce_effects"]
	settings.current_settings["accessibility"]["reduce_effects"] = false
	_hide_save()

	change_scene_to_file(TITLE)
	await create_timer(0.3).timeout
	var title := current_scene

	# --- 1. 옛 타이틀 요소 ---
	for old in ["HeaderContainer", "KeyHints", "Motto", "LeftShade", "TopRule"]:
		_check(title.get_node_or_null(old) == null, "옛 타이틀 요소가 없다: %s" % old)

	# --- 2. 로고 · 메뉴 배치 ---
	var base: TextureRect = title.find_child("WordmarkBase", true, false)
	var glyphs: Sprite2D = title.find_child("WordmarkTitle", true, false)
	_check(base != null and String(base.texture.resource_path).ends_with("title/wordmark_base.png")
			and base.position.is_equal_approx(Vector2(41.77, 64.39)) and base.size.is_equal_approx(Vector2(440, 350)),
			"시안 BrandMark 바탕층이 시안 자리(svg 상자 101.8, 94.4 / 320 x 259)에 있다")
	_check(glyphs != null and String(glyphs.texture.resource_path).ends_with("title/wordmark_title.png") and is_equal_approx(glyphs.scale.x, 0.5),
			"'벨카' 글자층은 따로 있다 (글리치용)")
	var box: VBoxContainer = title.get_node("MenuContainer/VBoxContainer")
	var labels: Array = []
	var all_rows := true
	for b in box.get_children():
		labels.append(String(b.get("label_text")))
		all_rows = all_rows and b.has_method("hot") and b.get_node_or_null("MenuFx") == null and b.get_node_or_null("Label") != null
	_check(labels == ORDER, "메뉴 순서: 시안 순서에 불러오기 · 종료만 더한다 (%s)" % [labels])
	_check(all_rows, "메뉴는 모두 시안 줄 메뉴(TitleMenuRow)이고 옛 효과 층이 없다")
	var menu_rect := (title.get_node("MenuContainer") as Control).get_global_rect()
	_check(absf(menu_rect.position.x - 99.2) < 0.6 and absf(menu_rect.size.x - 304.0) < 0.6, "메뉴 자리: x 99.2, 폭 304 (%s)" % menu_rect)
	var first: Control = box.get_child(0)
	var second: Control = box.get_child(1)
	_check(absf(first.size.y - 53.6) < 0.6 and absf(second.position.y - first.position.y - 56.6) < 0.8,
			"줄 높이 3.35rem, 줄 사이 0.18rem (%.1f / %.1f)" % [first.size.y, second.position.y - first.position.y])
	var label: Label = first.get_node("Label")
	_check(label.get_theme_font_size("font_size") == 22 and label.position.x > 46.0 and label.position.x < 47.5,
			"라벨: 나눔명조 22px, 왼쪽 2px 선 + 2.8rem 들여쓰기")

	# --- 3. 저장이 없을 때 ---
	var cont: Button = title.get("continue_btn")
	var new_game: Button = title.get("new_game_btn")
	_check(cont.disabled and cont.get_node("Redaction").visible and String(cont.get("detail_text")) == "저장 기록 없음",
			"저장이 없으면 이어하기는 먹줄로 지우고 '저장 기록 없음'")
	_check(String(new_game.get("detail_text")) == "프롤로그", "새 게임 옆에 '프롤로그'")

	# --- 4. 선택 표시 ---
	await create_timer(0.4).timeout
	_check(new_game.has_focus() and is_zero_approx(new_game.call("hot")), "처음엔 새 게임에 포커스만 있고 선택 표시는 숨는다")
	_key(KEY_DOWN)
	await create_timer(0.4).timeout
	var archive_btn: Button = title.get("archive_btn")
	_check(archive_btn.has_focus() and archive_btn.call("hot") > 0.99 and is_zero_approx(new_game.call("hot")),
			"↓ 키: 기록 보관소로 옮겨 가며 선택 표시가 켜진다")
	var row_label: Label = archive_btn.get_node("Label")
	_check(row_label.get_theme_color("font_color").is_equal_approx(Color("#efe8d8")), "선택된 줄 글자는 #efe8d8")
	_check(is_zero_approx(cont.call("hot")), "먹줄 친 이어하기는 선택 표시가 켜지지 않는다")

	# --- 5. 움직임 ---
	_check(title.get("booting") == true, "게임을 켜고 처음 본 타이틀은 부팅 연출을 한다")
	await create_timer(3.0).timeout
	var veil: Control = title.get_node("BootVeil")
	var logo: Control = title.get("logo")
	_check(not veil.visible and is_equal_approx(logo.modulate.a, 1.0) and (title.get_node("MenuContainer") as Control).modulate.a > 0.99,
			"부팅이 끝나면 검은 막이 걷히고 로고와 메뉴가 다 보인다")
	title.call("_glitch", 0.925)
	_check(not is_zero_approx(glyphs.skew) and is_equal_approx(glyphs.modulate.a, 0.7), "7초 주기 92% 지점: '벨카' 글자가 밀리고 기운다")
	title.call("_glitch", 0.5)
	_check(is_zero_approx(glyphs.skew) and is_equal_approx(glyphs.modulate.a, 1.0), "평소엔 글리치가 없다")
	var version: Label = title.get_node("VersionLabel")
	_check(version.text.begins_with("v" + String(ProjectSettings.get_setting("application/config/version"))), "오른쪽 아래 작은 버전 표기")

	change_scene_to_file(TITLE)
	await create_timer(0.3).timeout
	_check(current_scene.get("booting") == false and not current_scene.get_node("BootVeil").visible, "두 번째부터는 부팅 연출 없이 바로 뜬다")
	settings.current_settings["accessibility"]["reduce_effects"] = true
	await create_timer(0.2).timeout
	var bg: Control = current_scene.get_node("Background")
	_check(not current_scene.find_child("Figure", true, false).visible and is_equal_approx(bg.scale.x, 1.01),
			"'화면 효과 줄이기'면 그림자 형체 · 배경 숨쉬기를 끈다")

	settings.current_settings["accessibility"]["reduce_effects"] = calm_before
	_restore_save()
	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


## 자동 저장을 잠시 치워 두고 끝나면 되돌린다
func _hide_save() -> void:
	_save_path = String(root.get_node("/root/SaveManager").get("SAVE_PATH"))
	if FileAccess.file_exists(_save_path):
		_save_backup = FileAccess.get_file_as_string(_save_path)
		DirAccess.remove_absolute(_save_path)


func _restore_save() -> void:
	if _save_backup != null:
		var f := FileAccess.open(_save_path, FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)
