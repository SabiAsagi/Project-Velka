extends Control

# 프로젝트 벨카 - 긴장 연출 (PrototypeHUD 가 만든다)
# 근처 경비원·개체의 경계 단계(alert_level: 0 평소, 1 의심·수색, 2 추격)에 맞춰
#   - 심장 소리: 의심 땐 느리고 작게, 추격 땐 빠르고 크게
#   - 화면 가장자리: 의심 땐 어두운 호박색, 추격 땐 붉게 맥박친다
#   - 추격 중에는 낮은 웅웅거림이 깔린다
# 괴이세계에서는 가장자리가 늘 어둡게 눌려 있고, 화면에 옅은 지직거림이 깔린다.
# 가끔(10~22초) 숨소리 같은 잡음과 함께 비상등이 깜빡이고 지직거림이 튄다.

const VIGNETTE := preload("res://assets/shaders/canvas_vignette.gdshader")
const NOISE := preload("res://assets/shaders/canvas_ui_static_noise.gdshader")

var level := 0
var _vig: ColorRect
var _mat: ShaderMaterial
var _drone: AudioStreamPlayer
var _beat_left := 0.0
var _pulse := 0.0
var _base_strength := 0.0
var _base_tint := Color(0, 0, 0, 1)
var _poll_left := 0.0
var _grain: ColorRect
var _grain_mat: ShaderMaterial
var _grain_base := 0.0
var _grain_spike := 0.0
var _event_left := 12.0
var _otherworld := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig = ColorRect.new()
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = VIGNETTE
	_vig.material = _mat
	add_child(_vig)
	_grain = ColorRect.new()
	_grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_mat = ShaderMaterial.new()
	_grain_mat.shader = NOISE
	_grain_mat.set_shader_parameter("strength", 0.0)
	_grain_mat.set_shader_parameter("grain_size", 2.0)
	_grain_mat.set_shader_parameter("scanline_strength", 0.5)
	_grain.material = _grain_mat
	add_child(_grain)
	_drone = AudioStreamPlayer.new()
	_drone.stream = SfxBank.stream("drone")
	_drone.volume_db = -60.0
	add_child(_drone)
	GameManager.world_phase_changed.connect(func(_p): _apply_phase())
	_apply_phase()


## 괴이세계: 가장자리를 늘 어둡게 누른다
func _apply_phase() -> void:
	var ow := GameManager.is_otherworld()
	_otherworld = ow
	_base_strength = 0.92 if ow else 0.25
	_base_tint = Color(0.03, 0.0, 0.01, 1.0) if ow else Color(0, 0, 0, 1)
	_grain_base = 0.045 if ow else 0.0
	_event_left = randf_range(6.0, 12.0)


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = 0.15
		level = _compute_level()
	_atmosphere(delta)
	# 심장 소리
	_beat_left -= delta
	if level > 0 and _beat_left <= 0.0:
		_beat_left = 0.95 if level == 1 else 0.48
		SfxBank.play(self, "heartbeat", -15.0 if level == 1 else -5.0, 1.0 if level == 1 else 1.12)
		_pulse = 1.0
	_pulse = maxf(0.0, _pulse - delta * 2.8)
	# 웅웅거림
	var target_db := -9.0 if level == 2 else -60.0
	_drone.volume_db = move_toward(_drone.volume_db, target_db, delta * (40.0 if level == 2 else 18.0))
	if _drone.volume_db > -55.0 and not _drone.playing:
		_drone.play()
	elif _drone.volume_db <= -59.0 and _drone.playing:
		_drone.stop()
	# 가장자리
	var tint := _base_tint
	var strength := _base_strength
	if level == 1:
		tint = _base_tint.lerp(Color(0.25, 0.15, 0.0, 1.0), 0.6)
		strength = maxf(_base_strength, 0.55 + 0.15 * _pulse)
	elif level == 2:
		tint = Color(0.55, 0.0, 0.0, 1.0)
		strength = 0.75 + 0.25 * _pulse
	var cur: Color = _mat.get_shader_parameter("tint") if _mat.get_shader_parameter("tint") != null else tint
	_mat.set_shader_parameter("tint", cur.lerp(tint, minf(1.0, delta * 6.0)))
	var cur_s: float = _mat.get_shader_parameter("strength") if _mat.get_shader_parameter("strength") != null else 0.0
	_mat.set_shader_parameter("strength", lerpf(cur_s, strength, minf(1.0, delta * 8.0)))


## 괴이세계의 불규칙한 사건: 숨소리, 비상등 깜빡임, 지직거림
func _atmosphere(delta: float) -> void:
	_grain_spike = maxf(0.0, _grain_spike - delta * 1.5)
	_grain.visible = _grain_base + _grain_spike > 0.001
	_grain_mat.set_shader_parameter("strength", _grain_base + _grain_spike)
	if not _otherworld or GameManager.is_exploration_locked():
		return
	_event_left -= delta
	if _event_left > 0.0:
		return
	_event_left = randf_range(10.0, 22.0)
	SfxBank.play(self, "whisper", -14.0, randf_range(0.8, 1.15))
	_grain_spike = 0.12
	for light in get_tree().get_nodes_in_group("otherworld_light"):
		if light is Light3D and (light as Light3D).visible and randf() < 0.6:
			_flicker(light as Light3D)


func _flicker(light: Light3D) -> void:
	var energy := light.light_energy
	var t := create_tween()
	for i in randi_range(2, 4):
		t.tween_property(light, "light_energy", energy * randf_range(0.0, 0.25), 0.05)
		t.tween_property(light, "light_energy", energy, randf_range(0.05, 0.15))


func _compute_level() -> int:
	var best := 0
	for n in get_tree().get_nodes_in_group("anomaly"):
		if n.has_method("alert_level") and (n as Node3D).is_visible_in_tree():
			best = maxi(best, int(n.alert_level()))
	return best
