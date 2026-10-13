extends Node3D

class_name SchoolStudent

# 프로젝트 벨카 - 학교의 학생 (얼굴 없는 교복 실루엣)
# 충돌이 없다 (길을 막지 않는다). 상호작용 대상도 아니다.
#   경로(points)가 있으면 그 점들을 차례로 걷는다. loop 면 끝에서 되돌아 걷는다.
#   경로가 없으면 제자리에 서 있다 (motion: "idle" 숨쉬기, "repeat" 같은 동작을 끝없이 반복).
#   despawn_far > 0 이면, 첫 점을 지난 뒤 watcher 에게서 그만큼 멀어지면 사라진다 (화면 밖 정리).
#   fade_out() 을 부르면 걷던 방향으로 몇 걸음 더 걸으며 서서히 흐려진 뒤 사라진다 (건물 안으로 들어가는 연출).
#   층 판정: 조작 캐릭터와 다른 층이면 숨긴다 (set_floor_visible — 챕터 컨트롤러가 매 프레임 부른다).
# 이상한 학생: no_shadow (그림자가 없다).

signal route_finished(student: SchoolStudent)

const JACKET := Color(0.12, 0.15, 0.26)
const SHIRT := Color(0.86, 0.87, 0.88)
const SKIN := Color(0.78, 0.76, 0.74)
const HAIR := Color(0.07, 0.065, 0.07)
const LEGS := Color(0.1, 0.11, 0.15)
## 수위복: 낡은 카키 제복과 모자
const GUARD_COAT := Color(0.24, 0.25, 0.2)
const GUARD_CAP := Color(0.12, 0.13, 0.11)
const GREY_HAIR := Color(0.55, 0.55, 0.53)

## 층 높이 (학교 맵·WorldPhaseController.LEVEL_HEIGHT 와 같은 값 — 스크립트 의존을 피해 따로 둔다)
const LEVEL_HEIGHT := 3.8

static var _materials: Dictionary = {}

var points: PackedVector3Array = PackedVector3Array()
var loop: bool = false
var walk_speed: float = 1.3
## "idle" | "repeat"
var motion: String = "idle"
var no_shadow: bool = false
## "student" | "guard" (정문 수위)
var outfit: String = "student"
var watcher: Node3D = null
var despawn_far: float = 0.0
## 걸을 때 비켜 가는 대상 (사비·샤무). 몸이 닿을 만큼 가까우면 옆으로 살짝 비켜 지나간다.
var avoid: Array = []

var _target: int = 0
var _dir: int = 1
var _t: float = 0.0
var _phase: float = 0.0
var _body: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _meshes: Array[MeshInstance3D] = []
var _fade_total: float = 0.0
var _fade_left: float = 0.0


func _ready() -> void:
	add_to_group("school_figure")
	if outfit == "student":
		add_to_group("school_student")
	_phase = randf() * TAU
	_build()
	if not points.is_empty():
		global_position = points[0]
		_target = mini(1, points.size() - 1)


## 경로를 새로 준다 (지금 위치에서 첫 점으로 걸어간다)
func walk(route: PackedVector3Array, speed: float = -1.0, loop_route: bool = false) -> void:
	points = route
	loop = loop_route
	_target = 0
	_dir = 1
	if speed > 0.0:
		walk_speed = speed


func is_walking() -> bool:
	return not points.is_empty() and _target >= 0


## 높이(y)가 속한 층 번호 (0 = 지면·지하, 1 = 본관 1층·고지대 ...)
static func floor_index(y: float) -> int:
	return floori((y + 0.5) / LEVEL_HEIGHT)


## 조작 캐릭터와 같은 층에 있는가.
## 둘 다 건물 밖이면 (경사로·고지대·운동장은 이어진 땅이라) 늘 보인다. 한쪽이라도 건물 안이면 같은 층일 때만 보인다.
static func is_on_same_floor(my_y: float, my_inside: bool, viewer_y: float, viewer_inside: bool) -> bool:
	if not my_inside and not viewer_inside:
		return true
	return floor_index(my_y) == floor_index(viewer_y)


## 다른 층이면 숨긴다 (걷기·애니메이션은 그대로 계속된다)
func set_floor_visible(on_floor: bool) -> void:
	visible = on_floor


## 걷던 방향으로 계속 걸으며 duration 초 동안 흐려진 뒤 사라진다 (문 안으로 들어가는 연출)
func fade_out(duration: float = 0.9) -> void:
	if _fade_total > 0.0:
		return
	_fade_total = maxf(duration, 0.05)
	_fade_left = _fade_total
	_target = -1


func is_fading() -> bool:
	return _fade_total > 0.0


## (테스트·연출용) 바라보는 방향을 정한다
func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


func _process(delta: float) -> void:
	_t += delta
	if _fade_total > 0.0:
		_process_fade(delta)
		return
	var moving := false
	if not points.is_empty() and _target >= 0:
		var goal := points[_target]
		var to := goal - global_position
		var step := walk_speed * delta
		if to.length() <= step:
			global_position = goal
			_advance()
		else:
			global_position += to.normalized() * step + _sidestep(to.normalized()) * delta
			moving = true
			var flat := Vector3(to.x, 0.0, to.z)
			if flat.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 8.0))
	_animate(moving)
	if despawn_far > 0.0 and watcher and is_instance_valid(watcher) and _target >= 2:
		if watcher.global_position.distance_to(global_position) > despawn_far:
			queue_free()


## 흐려지는 동안은 바라보는 방향으로 계속 걷는다
func _process_fade(delta: float) -> void:
	_fade_left -= delta
	global_position += Vector3(sin(rotation.y), 0.0, cos(rotation.y)) * walk_speed * delta
	var amount := clampf(1.0 - _fade_left / _fade_total, 0.0, 1.0)
	for m in _meshes:
		m.transparency = amount
	_animate(true)
	if _fade_left <= 0.0:
		queue_free()


## 앞길에 사람이 있으면 진행 방향의 옆으로 비킨다 (속도 벡터)
func _sidestep(forward: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for n in avoid:
		var other := n as Node3D
		if other == null or not is_instance_valid(other):
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		if d > 0.95 or d < 0.001:
			continue
		var side := Vector3(-forward.z, 0.0, forward.x)
		var dir_sign := 1.0 if side.dot(away) >= 0.0 else -1.0
		push += side * dir_sign * (0.95 - d) * 3.2
	return push


func _advance() -> void:
	if loop:
		if _target + _dir >= points.size() or _target + _dir < 0:
			_dir = -_dir
		_target += _dir
		return
	if _target + 1 < points.size():
		_target += 1
	else:
		_target = -1
		route_finished.emit(self)


func _animate(moving: bool) -> void:
	if _body == null:
		return
	if moving:
		var k := _t * walk_speed * 5.2 + _phase
		_body.position.y = absf(sin(k)) * 0.035
		_leg_l.rotation.x = sin(k) * 0.45
		_leg_r.rotation.x = -sin(k) * 0.45
		_head.rotation.x = 0.0
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, 0.2)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, 0.2)
		_body.position.y = sin(_t * 1.6 + _phase) * 0.008
		if motion == "repeat":
			# 같은 끄덕임을 정확히 같은 박자로 계속한다
			var c := fmod(_t, 1.6) / 1.6
			_head.rotation.x = 0.35 * sin(minf(c * 2.0, 1.0) * PI)
		else:
			_head.rotation.x = 0.0


func _build() -> void:
	var guard := outfit == "guard"
	var s := 1.06 if guard else randf_range(0.93, 1.04)
	scale = Vector3(s, s, s)
	_leg_l = _limb(Vector3(-0.09, 0.78, 0.0))
	_leg_r = _limb(Vector3(0.09, 0.78, 0.0))
	_body = Node3D.new()
	add_child(_body)
	var torso := CapsuleMesh.new()
	torso.radius = 0.22
	torso.height = 0.82
	_add_mesh(_body, torso, GUARD_COAT if guard else JACKET, Vector3(0, 1.15, 0))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.14, 0.22, 0.04)
	_add_mesh(_body, collar, SHIRT, Vector3(0, 1.38, 0.2))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.6, 0)
	_body.add_child(_head)
	var face := SphereMesh.new()
	face.radius = 0.15
	face.height = 0.32
	_add_mesh(_head, face, SKIN, Vector3(0, 0.02, 0))
	var hair := SphereMesh.new()
	hair.radius = 0.16
	hair.height = 0.3
	# 머리카락은 정수리·뒤통수만 덮어 앞쪽의 비어 있는 얼굴이 보이게 한다
	_add_mesh(_head, hair, GREY_HAIR if guard else HAIR, Vector3(0, 0.085, -0.06))
	if guard:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.17
		cap.bottom_radius = 0.18
		cap.height = 0.09
		_add_mesh(_head, cap, GUARD_CAP, Vector3(0, 0.15, 0))
		var brim := BoxMesh.new()
		brim.size = Vector3(0.24, 0.02, 0.12)
		_add_mesh(_head, brim, GUARD_CAP, Vector3(0, 0.11, 0.16))
	if no_shadow:
		for m in _meshes:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _limb(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var leg := CapsuleMesh.new()
	leg.radius = 0.07
	leg.height = 0.78
	_add_mesh(pivot, leg, LEGS, Vector3(0, -0.38, 0))
	return pivot


func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = _material(color)
	parent.add_child(mi)
	_meshes.append(mi)


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materials[key] = m
	return _materials[key]
