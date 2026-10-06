extends InteractableBase

class_name SchoolDoor

# 프로젝트 벨카 - 학교 문 (교실 미닫이 / 현관 유리 양개문 / 설비실 금속문 / 화장실 불투명문 등)
# 문짝·문틀·이름표를 코드로 만들어서, 맵 생성기는 종류와 치수만 지정한다.
# 로컬 좌표: 원점 = 개구부 중앙(벽 두께 중심, 바닥 높이), +x = 벽을 따라, +z = leaf_side가 +1일 때 문짝이 붙는 벽면 쪽.
# 벽 구멍은 (door_width + 2*JAMB) x (door_height + JAMB) 크기로 뚫려 있어야 문틀이 맞는다.

enum Kind { SLIDING_WOOD, SWING_METAL, SWING_OPAQUE, SWING_THICK, DOUBLE_GLASS, DOUBLE_FIRE }

const SURFACE_SHADER := preload("res://assets/shaders/school_surface.gdshader")
## 문짝 텍스처 (tools/level_gen/school/texture_tool.gd가 CC0 ambientCG 텍스처로 만든 파생 텍스처)와 그 선형 평균색
## (texture_stats.json). 평균색으로 나눈 색을 곱해 팔레트 색이 그대로 문짝의 평균색이 되게 한다.
const LEAF_TEXTURES := {
	"wood": ["res://assets/textures/school/DoorWood_Color.jpg", Color(0.1995, 0.1247, 0.0755)],
	"paint": ["res://assets/textures/school/DoorPaint_Color.jpg", Color(0.1408, 0.1408, 0.1408)],
}
## 문짝 텍스처 한 장이 덮는 길이 (m)
const LEAF_TEXTURE_SIZE := 0.9
## 문틀(측면·상부) 두께. 벽 구멍 = 통과 폭 + 2 * JAMB
const JAMB := 0.04

@export var kind: Kind = Kind.SLIDING_WOOD
## 문틀 안쪽의 통과 가능한 폭 (m)
@export var door_width: float = 1.1
@export var door_height: float = 2.1
## 문이 끼워진 벽 두께 (문틀 깊이)
@export var wall_thickness: float = 0.15
## 문짝이 붙는 쪽 (+1 = 로컬 +z 벽면, -1 = -z 벽면). 미닫이 레일 위치이자 여닫이가 열리는 방향.
@export var leaf_side: float = 1.0
## 미닫이가 열릴 때 밀리는 방향 (+1 = +x)
@export var slide_dir: float = 1.0
## 외여닫이 경첩 위치 (-1 = -x 끝, +1 = +x 끝)
@export var hinge_side: float = -1.0
@export var is_locked: bool = false
## 이 스토리 플래그가 켜지면 잠금이 풀린다
@export var unlock_flag: String = ""
@export var locked_prompt: String = "잠긴 문"
## 잠긴 상태에서 조사했을 때의 대사 (비우면 반응 없음)
@export_multiline var locked_line: String = ""
## 문 위 이름표. 비우면 없음
@export var plate_text: String = ""
## 이름표·안내문이 붙는 벽면 (+1 = +z, -1 = -z, 0 = 문짝 반대쪽)
@export var plate_side: float = 0.0
## 작은 안내문 (문짝 반대쪽 벽면, 문 옆). 예: "시설 점검으로 임시 폐쇄"
@export var notice_text: String = ""
@export var start_open: bool = false
@export var animation_duration: float = 0.35

var is_open: bool = false
var _is_animating: bool = false
var _leaves: Array[Node3D] = []
var _closed: Array[Transform3D] = []
var _opened: Array[Transform3D] = []
var _shapes: Array[CollisionShape3D] = []

static var _material_cache: Dictionary = {}


func _ready() -> void:
	super._ready()
	show_nearby_marker = false
	add_to_group("school_door")
	if get_node_or_null("InteractionPoint") == null:
		var point := Marker3D.new()
		point.name = "InteractionPoint"
		point.position = Vector3(0.0, 1.0, 0.0)
		add_child(point)
	_build()
	if start_open:
		_apply_state(true, false)


# ---------------------------------------------------------------- 상호작용

func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and not _is_animating


func get_interaction_prompt(_player: Node3D) -> String:
	_refresh_lock()
	if is_locked:
		return locked_prompt
	return "문 닫기" if is_open else "문 열기"


func _refresh_lock() -> void:
	if is_locked and not unlock_flag.is_empty() and GameManager.get_story_flag(unlock_flag, false):
		is_locked = false


func _on_interact(_player: Node3D) -> void:
	_refresh_lock()
	if is_locked:
		if not locked_line.is_empty():
			var is_shamu := GameManager.active_character == GameManager.CharacterType.SHAMU
			DialogueManager.start_dialogue_data("locked_" + name, [{
				"speaker": "shamu" if is_shamu else "sabi",
				"speaker_name": "카즈네 샤무" if is_shamu else "사비 아사기",
				"sabi_emotion": "serious",
				"shamu_emotion": "annoyed",
				"text": locked_line,
			}])
		return
	if _is_animating:
		return
	_apply_state(not is_open, true)


## 문을 연다/닫는다. animated가 false면 즉시.
func set_open(value: bool, animated: bool = true) -> void:
	if value != is_open and not _is_animating:
		_apply_state(value, animated)


func _apply_state(open: bool, animated: bool) -> void:
	is_open = open
	var swinging := kind != Kind.SLIDING_WOOD
	# 여닫이는 도는 동안 캐릭터를 밀어내지 않도록 열린 동안 충돌을 끈다.
	if open and swinging:
		for shape in _shapes:
			shape.set_deferred("disabled", true)
	if not animated:
		for i in _leaves.size():
			_leaves[i].transform = _opened[i] if open else _closed[i]
	else:
		_is_animating = true
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for i in _leaves.size():
			tween.tween_property(_leaves[i], "transform", _opened[i] if open else _closed[i], animation_duration)
		await tween.finished
		_is_animating = false
	if not open and swinging:
		for shape in _shapes:
			shape.set_deferred("disabled", false)


# ---------------------------------------------------------------- 형태

func _build() -> void:
	var t := wall_thickness
	var w := door_width
	var h := door_height
	var wooden := kind == Kind.SLIDING_WOOD or kind == Kind.SWING_THICK
	var frame := _mat("door_frame_wood", Color(0.42, 0.29, 0.18), 0.6) if wooden else _mat("door_frame_metal", Color(0.52, 0.54, 0.56), 0.45, 0.4)
	# 문틀: 구멍 안쪽을 채우는 측면·상부 문틀 + 양쪽 벽면 테두리
	_box(self, "JambL", Vector3(JAMB, h + JAMB, t + 0.02), Vector3(-w / 2.0 - JAMB / 2.0, (h + JAMB) / 2.0, 0.0), frame)
	_box(self, "JambR", Vector3(JAMB, h + JAMB, t + 0.02), Vector3(w / 2.0 + JAMB / 2.0, (h + JAMB) / 2.0, 0.0), frame)
	_box(self, "JambTop", Vector3(w, JAMB, t + 0.02), Vector3(0.0, h + JAMB / 2.0, 0.0), frame)
	for side in [-1.0, 1.0]:
		var z: float = side * (t / 2.0 + 0.007)
		var outer := w / 2.0 + JAMB
		_box(self, "CasingL", Vector3(0.06, h + JAMB + 0.06, 0.014), Vector3(-outer - 0.03, (h + JAMB + 0.06) / 2.0, z), frame)
		_box(self, "CasingR", Vector3(0.06, h + JAMB + 0.06, 0.014), Vector3(outer + 0.03, (h + JAMB + 0.06) / 2.0, z), frame)
		_box(self, "CasingTop", Vector3(outer * 2.0, 0.06, 0.014), Vector3(0.0, h + JAMB + 0.03, z), frame)
	match kind:
		Kind.SLIDING_WOOD:
			_build_sliding()
		Kind.DOUBLE_GLASS, Kind.DOUBLE_FIRE:
			_build_double()
		_:
			_build_swing()
	if not plate_text.is_empty():
		_build_plate()
	if not notice_text.is_empty():
		_build_notice()


func _build_sliding() -> void:
	var t := wall_thickness
	var w := door_width
	var h := door_height
	var lt := 0.04
	var lw := w + 0.05
	var z := leaf_side * (t / 2.0 + 0.012 + lt / 2.0 + 0.02)
	var wood := _leaf_mat("wood_door", Color(0.56, 0.39, 0.23), 0.7, 0.0, "wood")
	var wood_dark := _leaf_mat("wood_door_dark", Color(0.36, 0.24, 0.14), 0.75, 0.0, "wood")
	var scuff := _leaf_mat("wood_scuff", Color(0.43, 0.31, 0.2), 0.9, 0.0, "wood")
	var metal := _mat("rail", Color(0.6, 0.61, 0.62), 0.4, 0.6)
	# 레일: 개구부와 문이 밀려가는 구간 위
	var rail_len := w * 2.0 + 0.12
	_box(self, "Rail", Vector3(rail_len, 0.05, 0.06), Vector3(slide_dir * (w / 2.0 + 0.02), h + JAMB + 0.1, leaf_side * (t / 2.0 + 0.03)), metal)
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	add_child(leaf)
	var body := _body(leaf, Vector3(lw, h - 0.01, lt + 0.01), Vector3(0.0, (h - 0.01) / 2.0, 0.0))
	_box(body, "Panel", Vector3(lw, h - 0.01, lt), Vector3(0.0, (h - 0.01) / 2.0, 0.0), wood)
	_box(body, "Scuff", Vector3(lw - 0.02, 0.16, lt + 0.006), Vector3(0.0, 0.09, 0.0), scuff)
	# 상부 작은 사각 유리창과 창틀
	var win_y := h * 0.72
	_box(body, "Window", Vector3(0.34, 0.4, lt + 0.008), Vector3(0.0, win_y, 0.0), _glass())
	for dx in [-0.18, 0.18]:
		_box(body, "WindowFrame", Vector3(0.025, 0.45, lt + 0.012), Vector3(dx, win_y, 0.0), wood_dark)
	for dy in [-0.215, 0.215]:
		_box(body, "WindowFrame", Vector3(0.385, 0.025, lt + 0.012), Vector3(0.0, win_y + dy, 0.0), wood_dark)
	# 파인 손잡이: 닫힐 때 문틀에 닿는 쪽 가장자리 근처
	var grip_x := -slide_dir * (lw / 2.0 - 0.1)
	_box(body, "Grip", Vector3(0.035, 0.15, lt + 0.006), Vector3(grip_x, 0.98, 0.0), wood_dark)
	_register(leaf, Transform3D(Basis(), Vector3(0.0, 0.0, z)), Transform3D(Basis(), Vector3(slide_dir * (w + 0.02), 0.0, z)))


func _build_swing() -> void:
	var w := door_width
	var h := door_height
	var lt := 0.07 if kind == Kind.SWING_THICK else 0.05
	var panel: Material
	var trim: Material
	match kind:
		Kind.SWING_METAL:
			panel = _leaf_mat("metal_door", Color(0.43, 0.5, 0.48), 0.55, 0.35, "paint")
			trim = _leaf_mat("metal_handle", Color(0.7, 0.71, 0.72), 0.3, 0.8)
		Kind.SWING_OPAQUE:
			panel = _leaf_mat("opaque_door", Color(0.8, 0.76, 0.68), 0.65, 0.0, "paint")
			trim = _leaf_mat("steel_plate", Color(0.74, 0.75, 0.77), 0.3, 0.7)
		_:
			panel = _leaf_mat("thick_door", Color(0.4, 0.27, 0.17), 0.7, 0.0, "wood")
			trim = _leaf_mat("metal_handle", Color(0.7, 0.71, 0.72), 0.3, 0.8)
	var hinge := Vector3(hinge_side * w / 2.0, 0.0, 0.0)
	var pivot := Node3D.new()
	pivot.name = "Leaf"
	add_child(pivot)
	# 피벗(경첩) 기준 좌표: 문짝은 경첩에서 반대쪽 끝까지 뻗는다
	var cx := -hinge_side * w / 2.0
	var body := _body(pivot, Vector3(w - 0.01, h - 0.01, lt), Vector3(cx, (h - 0.01) / 2.0, 0.0))
	_box(body, "Panel", Vector3(w - 0.01, h - 0.01, lt), Vector3(cx, (h - 0.01) / 2.0, 0.0), panel)
	var free_x := cx - hinge_side * (w / 2.0 - 0.1)
	match kind:
		Kind.SWING_METAL:
			_box(body, "Window", Vector3(0.2, 0.32, lt + 0.008), Vector3(cx, h * 0.72, 0.0), _glass())
			_box(body, "Handle", Vector3(0.14, 0.03, lt + 0.1), Vector3(free_x, 1.0, 0.0), trim)
		Kind.SWING_OPAQUE:
			_box(body, "PushPlate", Vector3(0.1, 0.3, lt + 0.006), Vector3(free_x, 1.15, 0.0), trim)
			_box(body, "KickPlate", Vector3(w - 0.06, 0.2, lt + 0.006), Vector3(cx, 0.12, 0.0), trim)
		_:
			_box(body, "Window", Vector3(0.14, 0.5, lt + 0.008), Vector3(cx, h * 0.68, 0.0), _glass())
			_box(body, "Handle", Vector3(0.14, 0.03, lt + 0.1), Vector3(free_x, 1.0, 0.0), trim)
	var angle := asin(clampf(leaf_side * hinge_side, -1.0, 1.0))
	_register(pivot, Transform3D(Basis(), hinge), Transform3D(Basis(Vector3.UP, angle), hinge))


func _build_double() -> void:
	var w := door_width
	var h := door_height
	var half := w / 2.0
	var glass_door := kind == Kind.DOUBLE_GLASS
	var frame := _leaf_mat("glass_door_frame", Color(0.5, 0.52, 0.55), 0.35, 0.65) if glass_door else _leaf_mat("fire_door", Color(0.62, 0.6, 0.55), 0.55, 0.3, "paint")
	var bar := _leaf_mat("metal_handle", Color(0.7, 0.71, 0.72), 0.3, 0.8)
	var lt := 0.06
	for side in [-1.0, 1.0]:
		var hinge := Vector3(side * half, 0.0, 0.0)
		var pivot := Node3D.new()
		pivot.name = "LeafL" if side < 0.0 else "LeafR"
		add_child(pivot)
		# 피벗(경첩) 기준 좌표: 문짝 중심은 경첩에서 안쪽으로 half/2
		var cx: float = -side * half / 2.0
		var body := _body(pivot, Vector3(half - 0.01, h - 0.01, lt), Vector3(cx, (h - 0.01) / 2.0, 0.0))
		if glass_door:
			var stile := 0.07
			_box(body, "StileOuter", Vector3(stile, h - 0.01, lt), Vector3(-side * (stile / 2.0 + 0.005), (h - 0.01) / 2.0, 0.0), frame)
			_box(body, "StileInner", Vector3(stile, h - 0.01, lt), Vector3(-side * (half - stile / 2.0 - 0.005), (h - 0.01) / 2.0, 0.0), frame)
			_box(body, "RailTop", Vector3(half - 2.0 * stile - 0.01, 0.09, lt), Vector3(cx, h - 0.055, 0.0), frame)
			_box(body, "RailBottom", Vector3(half - 2.0 * stile - 0.01, 0.2, lt), Vector3(cx, 0.1, 0.0), frame)
			_box(body, "Glass", Vector3(half - 2.0 * stile - 0.01, h - 0.3, 0.012), Vector3(cx, 0.2 + (h - 0.3) / 2.0, 0.0), _glass())
			_box(body, "PullBar", Vector3(0.03, 0.9, lt + 0.12), Vector3(-side * (half - 0.16), 1.05, 0.0), bar)
		else:
			_box(body, "Panel", Vector3(half - 0.01, h - 0.01, lt), Vector3(cx, (h - 0.01) / 2.0, 0.0), frame)
			_box(body, "Window", Vector3(0.18, 0.36, lt + 0.008), Vector3(cx, h * 0.7, 0.0), _glass())
			_box(body, "PushBar", Vector3(half - 0.2, 0.05, lt + 0.1), Vector3(cx, 1.0, 0.0), bar)
		var angle := asin(clampf(leaf_side * side, -1.0, 1.0))
		_register(pivot, Transform3D(Basis(), hinge), Transform3D(Basis(Vector3.UP, angle), hinge))


func _sign_side() -> float:
	return plate_side if plate_side != 0.0 else -leaf_side


func _build_plate() -> void:
	var t := wall_thickness
	var side := _sign_side()
	var y := door_height + JAMB + 0.3
	_box(self, "Plate", Vector3(0.46, 0.15, 0.02), Vector3(0.0, y, side * (t / 2.0 + 0.012)), _mat("plate", Color(0.93, 0.92, 0.88), 0.5))
	var label := Label3D.new()
	label.name = "PlateText"
	label.text = plate_text
	label.font_size = 40
	label.pixel_size = 0.0032
	label.modulate = Color(0.12, 0.13, 0.16)
	label.outline_size = 0
	label.position = Vector3(0.0, y, side * (t / 2.0 + 0.024))
	if side < 0.0:
		label.rotation.y = PI
	add_child(label)


func _build_notice() -> void:
	var t := wall_thickness
	var side := _sign_side()
	var x := door_width / 2.0 + JAMB + 0.5
	_box(self, "Notice", Vector3(0.42, 0.3, 0.012), Vector3(x, 1.45, side * (t / 2.0 + 0.01)), _mat("notice", Color(0.95, 0.9, 0.5), 0.6))
	var label := Label3D.new()
	label.name = "NoticeText"
	label.text = notice_text
	label.font_size = 26
	label.pixel_size = 0.0022
	label.width = 180.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.2, 0.08, 0.05)
	label.outline_size = 0
	label.position = Vector3(x, 1.45, side * (t / 2.0 + 0.018))
	if side < 0.0:
		label.rotation.y = PI
	add_child(label)


# ---------------------------------------------------------------- 도우미

func _register(leaf: Node3D, closed: Transform3D, opened: Transform3D) -> void:
	leaf.transform = closed
	_leaves.append(leaf)
	_closed.append(closed)
	_opened.append(opened)


func _body(parent: Node3D, size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	_shapes.append(shape)
	return body


func _box(parent: Node, box_name: String, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


## 문짝용 표준 재질: 캐릭터를 가리면 FollowCamera가 반투명하게 만든다.
## texture_key가 LEAF_TEXTURES에 있으면 나뭇결·도장면 텍스처를 문짝 자기 좌표 삼면 투영으로 입힌다.
static func _leaf_mat(key: String, color: Color, roughness: float = 0.8, metallic: float = 0.0, texture_key: String = "") -> StandardMaterial3D:
	var cache_key := "leaf_" + key
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if LEAF_TEXTURES.has(texture_key):
		var info: Array = LEAF_TEXTURES[texture_key]
		var avg: Color = info[1]
		var lin := color.srgb_to_linear()
		material.albedo_texture = load(info[0])
		material.albedo_color = Color(lin.r / avg.r, lin.g / avg.g, lin.b / avg.b).linear_to_srgb()
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / LEAF_TEXTURE_SIZE
	material.roughness = roughness
	material.metallic = metallic
	_material_cache[cache_key] = material
	return material


## 문틀·이름표용 셰이더 재질: 벽과 함께 컷어웨이로 잘린다.
static func _mat(key: String, color: Color, roughness: float = 0.8, metallic: float = 0.0, grime: float = 0.04) -> ShaderMaterial:
	if _material_cache.has(key):
		return _material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("grime", grime)
	material.set_shader_parameter("cutaway_scale", 0.8)
	_material_cache[key] = material
	return material


static func _glass() -> StandardMaterial3D:
	if _material_cache.has("glass"):
		return _material_cache["glass"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.72, 0.8, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic = 0.3
	_material_cache["glass"] = material
	return material
