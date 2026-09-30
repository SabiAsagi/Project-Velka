extends AudioStreamPlayer

class_name AmbientSynth

# 프로젝트 벨카 - 절차적 환경음
# 오디오 에셋 없이 AudioStreamGenerator로 배경음을 합성한다.
#   HUM: 현실의 형광등 웅웅거림 + 환풍기 잡음
#   SILENCE: 전이 직후의 완전한 정적
#   DRONE: 이계의 낮은 저음과 느리게 부풀었다 가라앉는 잡음

enum Mode { SILENCE, HUM, DRONE }

@export var mode: Mode = Mode.HUM
@export_range(0.0, 1.0) var master_gain: float = 0.35

const MIX_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback = null
var _phase_a: float = 0.0
var _phase_b: float = 0.0
var _time: float = 0.0
var _noise_state: float = 0.0
var _gain: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	_rng.seed = 7
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func set_mode(new_mode: Mode) -> void:
	mode = new_mode


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var step := 1.0 / MIX_RATE
	var target_gain := 0.0 if mode == Mode.SILENCE else master_gain
	for i in frames:
		_time += step
		# 모드 전환 시 딸깍 소리가 나지 않도록 음량을 부드럽게 옮긴다.
		_gain = move_toward(_gain, target_gain, step * 1.5)
		_noise_state = lerpf(_noise_state, _rng.randf_range(-1.0, 1.0), 0.02)
		var sample := 0.0
		match mode:
			Mode.HUM:
				_phase_a = fmod(_phase_a + 120.0 * step, 1.0)
				_phase_b = fmod(_phase_b + 240.0 * step, 1.0)
				sample = sin(TAU * _phase_a) * 0.35 + sin(TAU * _phase_b) * 0.12 + _noise_state * 0.5
			Mode.DRONE:
				_phase_a = fmod(_phase_a + 41.0 * step, 1.0)
				_phase_b = fmod(_phase_b + 61.5 * step, 1.0)
				var swell := 0.55 + 0.45 * sin(TAU * _time * 0.07)
				sample = (sin(TAU * _phase_a) * 0.5 + sin(TAU * _phase_b) * 0.25) * swell + _noise_state * 0.8 * swell
		var value := sample * _gain
		_playback.push_frame(Vector2(value, value))
