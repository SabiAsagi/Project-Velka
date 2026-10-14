class_name Cutscene
extends RefCounted

# 프로젝트 벨카 - 컷씬과 플레이를 섞는 공통 도구
# 대화창만 띄우는 대신, 캐릭터가 실제로 걸어가고 카메라가 따라가는 짧은 연출을 만든다.
#   begin(tree) / end(tree) : 화면 위아래 검은 띠(레터박스) + 탐색 조작 잠금, HUD 를 잠시 흐리게
#   focus(tree, node)       : 카메라가 따라갈 대상을 바꾼다 (null 이면 조작 캐릭터로 돌아간다)
#   slow_motion(tree, ...)  : 잠깐 느리게 (실제 시간 기준으로 돌아온다)
#   shake(tree, ...)        : 카메라 흔들기
#   bark(node, text, color) : 머리 위 짧은 말 (게임은 멈추지 않는다)
#   wait(tree, seconds)     : 연출 중 잠시 멈춤
#   lay_down(member, ...)   : 캐릭터를 눕힌다 / 다시 세운다 (쓰러짐, 업혀 감, 침대)
# 캐릭터 이동은 PartyMember.walk_path() 를 쓴다.

const LOCK := "cutscene"
const BARS_NAME := "CutsceneBars"
## 대화창(50)보다 아래, HUD(10)보다 위
const BARS_LAYER := 40
const BAR_RATIO := 0.1

static var _active := false


static func is_active() -> bool:
	return _active


static func begin(tree: SceneTree, bars: bool = true) -> void:
	_active = true
	GameManager.set_exploration_lock(LOCK, true)
	if bars:
		_set_bars(tree, true)
	_fade_hud(tree, 0.0)


static func end(tree: SceneTree) -> void:
	_active = false
	GameManager.set_exploration_lock(LOCK, false)
	focus(tree, null)
	_set_bars(tree, false)
	_fade_hud(tree, 1.0)


## 카메라가 따라갈 대상. null 이면 지금 조작 캐릭터로 돌아간다.
static func focus(tree: SceneTree, node: Node3D) -> void:
	var camera := tree.root.get_viewport().get_camera_3d()
	if camera == null or not ("target" in camera):
		return
	if node == null:
		var party := tree.get_first_node_in_group("player_party")
		node = party.get_active_member() if party and party.has_method("get_active_member") else null
	if node:
		camera.set("target", node)


static func slow_motion(tree: SceneTree, time_scale: float = 0.3, seconds: float = 0.8) -> void:
	Engine.time_scale = time_scale
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


static func shake(tree: SceneTree, strength: float = 0.25, seconds: float = 0.4) -> void:
	# 접근성: 화면 효과 줄이기
	var settings := tree.root.get_node_or_null("SettingsManager")
	if settings and settings.reduce_effects():
		strength *= 0.25
	var camera := tree.root.get_viewport().get_camera_3d()
	if camera == null:
		return
	var t := 0.0
	while t < seconds and is_instance_valid(camera):
		var k := 1.0 - t / seconds
		camera.h_offset = randf_range(-strength, strength) * k
		camera.v_offset = randf_range(-strength, strength) * k
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	if is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0


static func bark(node: Node3D, text: String, color: Color = Color(0.92, 0.92, 0.95), seconds: float = 1.6) -> void:
	if node == null or not node.is_inside_tree():
		return
	AbilityFx.spawn_text(node.get_tree().current_scene, node.global_position + Vector3.UP * 2.1, text, color, seconds)


## 화면 전체를 color 로 번쩍이거나 물들였다가 걷어낸다 (붉은 피격, 검게 암전 등)
static func flash(tree: SceneTree, color: Color, fade_in: float = 0.05, hold: float = 0.0, fade_out: float = 0.4) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	# 접근성: 화면 효과 줄이기 — 밝은 번쩍임은 옅고 느리게 (암전은 그대로)
	var settings := tree.root.get_node_or_null("SettingsManager")
	if settings and settings.reduce_effects() and color.v > 0.2:
		color.a *= 0.4
		fade_in = maxf(fade_in, 0.2)
	var layer := CanvasLayer.new()
	layer.layer = BARS_LAYER + 1
	scene.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tween := layer.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(rect, "color:a", color.a, fade_in)
	tween.tween_interval(hold)
	tween.tween_property(rect, "color:a", 0.0, fade_out)
	tween.tween_callback(layer.queue_free)
	await tween.finished


## 짧게 멈칫 (타격감): 아주 잠깐 시간을 거의 멈춘다
static func hit_stop(tree: SceneTree, seconds: float = 0.07) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## 캐릭터 스프라이트를 눕힌다 (카메라 쪽을 향해 옆으로 누운 모습). lying=false 면 원래대로 세운다.
## angle: 기울기(도, 90 이면 완전히 누움), height: 누웠을 때 스프라이트 중심 높이(캐릭터 발 기준)
static func lay_down(member: Node3D, lying: bool, angle: float = 90.0, height: float = 0.32) -> void:
	var sprite := member.get("sprite") as SpriteBase3D if member else null
	if sprite == null:
		return
	if lying:
		if not sprite.has_meta("stand_billboard"):
			sprite.set_meta("stand_billboard", sprite.billboard)
			sprite.set_meta("stand_rotation", sprite.rotation)
			sprite.set_meta("stand_position", sprite.position)
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		var yaw := 0.0
		var camera := member.get_viewport().get_camera_3d()
		if camera:
			var to := camera.global_position - member.global_position
			yaw = atan2(to.x, to.z) - member.global_rotation.y
		sprite.rotation = Vector3(0.0, yaw, deg_to_rad(angle))
		sprite.position = Vector3(sprite.position.x, height, sprite.position.z)
	elif sprite.has_meta("stand_billboard"):
		sprite.billboard = sprite.get_meta("stand_billboard")
		sprite.rotation = sprite.get_meta("stand_rotation")
		sprite.position = sprite.get_meta("stand_position")
		sprite.remove_meta("stand_billboard")
		sprite.remove_meta("stand_rotation")
		sprite.remove_meta("stand_position")


static func is_lying(member: Node3D) -> bool:
	var sprite := member.get("sprite") as SpriteBase3D if member else null
	return sprite != null and sprite.has_meta("stand_billboard")


static func wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout


static func _set_bars(tree: SceneTree, shown: bool) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var layer := scene.get_node_or_null(BARS_NAME) as CanvasLayer
	if layer == null:
		if not shown:
			return
		layer = CanvasLayer.new()
		layer.name = BARS_NAME
		layer.layer = BARS_LAYER
		scene.add_child(layer)
		for top in [true, false]:
			var bar := ColorRect.new()
			bar.name = "Top" if top else "Bottom"
			bar.color = Color(0, 0, 0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.anchor_left = 0.0
			bar.anchor_right = 1.0
			bar.anchor_top = 0.0 if top else 1.0
			bar.anchor_bottom = 0.0 if top else 1.0
			layer.add_child(bar)
	var h := scene.get_viewport().get_visible_rect().size.y * BAR_RATIO if shown else 0.0
	var top_bar := layer.get_node("Top") as ColorRect
	var bottom_bar := layer.get_node("Bottom") as ColorRect
	var tween := layer.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tween.tween_property(top_bar, "offset_bottom", h, 0.45)
	tween.tween_property(bottom_bar, "offset_top", -h, 0.45)


## 레터박스가 지금 보이는지 (테스트용)
static func bars_shown(tree: SceneTree) -> bool:
	var layer := tree.current_scene.get_node_or_null(BARS_NAME) if tree.current_scene else null
	return layer != null and (layer.get_node("Top") as ColorRect).offset_bottom > 1.0


static func _fade_hud(tree: SceneTree, alpha: float) -> void:
	for hud in tree.get_nodes_in_group("radio_feed"):
		var overlay = hud.get("overlay")
		if overlay is CanvasItem:
			overlay.create_tween().tween_property(overlay, "modulate:a", alpha, 0.35)
