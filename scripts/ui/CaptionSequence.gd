extends CanvasLayer

class_name CaptionSequence

# 프로젝트 벨카 - 검은 화면 자막 몽타주 / 화면 노이즈 연출
# play(lines): 화면을 검게 덮고 자막을 한 줄씩 보여 준 뒤 걷어 낸다 (조사·E·Enter로 다음 줄).
# noise_flash(seconds): 화면 전체에 짧은 지지직 노이즈를 띄운다.
# 재생 중에는 탐색 입력을 잠근다.

signal finished()

const LOCK_REASON := "caption_sequence"
const NOISE_SHADER := preload("res://assets/shaders/canvas_ui_static_noise.gdshader")

## 한 줄을 자동으로 넘기기까지의 시간(초)
@export var seconds_per_line: float = 3.2
@export var fade_seconds: float = 0.6

var _black: ColorRect
var _label: Label
var _noise: ColorRect
var _lines: Array = []
var _index: int = -1
var _timer: float = 0.0
var _playing: bool = false


func _ready() -> void:
	layer = 80
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 26)
	_label.modulate = Color(0.9, 0.92, 0.94, 0.0)
	_black.add_child(_label)
	var hint := Label.new()
	hint.text = "E / Enter  다음"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-180, -48)
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.55, 0.58, 0.62)
	_black.add_child(hint)
	_noise = ColorRect.new()
	_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = NOISE_SHADER
	_noise.material = material
	_noise.visible = false
	add_child(_noise)


func is_playing() -> bool:
	return _playing


func play(lines: Array) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = -1
	_playing = true
	GameManager.set_exploration_lock(LOCK_REASON, true)
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, fade_seconds)
	await tween.finished
	advance()


## 다음 자막으로 (마지막 줄 다음이면 끝낸다)
func advance() -> void:
	if not _playing:
		return
	_index += 1
	_timer = 0.0
	if _index >= _lines.size():
		_finish()
		return
	_label.text = String(_lines[_index])
	_label.modulate.a = 0.0
	create_tween().tween_property(_label, "modulate:a", 1.0, 0.35)


func noise_flash(seconds: float = 0.5) -> void:
	_noise.visible = true
	await get_tree().create_timer(seconds).timeout
	_noise.visible = false


func _process(delta: float) -> void:
	if not _playing or _index < 0:
		return
	_timer += delta
	if _timer >= seconds_per_line:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if _playing and _index >= 0 and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		advance()


func _finish() -> void:
	_playing = false
	_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 0.0, fade_seconds)
	await tween.finished
	GameManager.set_exploration_lock(LOCK_REASON, false)
	finished.emit()
