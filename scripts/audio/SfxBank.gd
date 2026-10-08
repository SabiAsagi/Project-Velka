class_name SfxBank
extends RefCounted

# 프로젝트 벨카 - 절차적 효과음 (오디오 파일 없이 합성)
# 한 번 만든 소리는 캐시해서 다시 쓴다. play() 로 바로 재생하거나 stream() 으로 받아 AudioStreamPlayer 에 넣는다.
#   footstep  : 딱딱한 바닥 발소리
#   heartbeat : 쿵-쿵 (두 번 뛰는 심장)
#   sting     : 들켰을 때 날카로운 불협화음
#   suspicious: "어?" 하고 올라가는 짧은 음
#   crash     : 부서지는 굉음
#   static    : 지직거리는 잡음
#   whisper   : 괴이세계의 숨소리 같은 잡음

const RATE := 22050

static var _cache: Dictionary = {}


static func stream(sfx_name: String) -> AudioStreamWAV:
	if not _cache.has(sfx_name):
		_cache[sfx_name] = _make(sfx_name)
	return _cache[sfx_name]


## 화면 어디서나 들리는 소리 (2D)
static func play(parent: Node, sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream(sfx_name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## 위치에서 나는 소리 (3D, 멀면 작게)
static func play_at(parent: Node, at: Vector3, sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 18.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sfx_name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = 4.0
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


static func _make(sfx_name: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sfx_name)
	var s := PackedFloat32Array()
	match sfx_name:
		"footstep":
			s = _buffer(0.16)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.18)
				var thump := sin(TAU * 70.0 * t) * exp(-t * 45.0)
				s[i] = (lp * 1.6 * exp(-t * 38.0) + thump * 0.8) * 0.8
		"heartbeat":
			s = _buffer(0.62)
			for i in s.size():
				var t := float(i) / RATE
				var a := _thump(t, 0.0, 58.0)
				var b := _thump(t, 0.22, 48.0) * 0.75
				s[i] = (a + b) * 0.95
		"sting":
			s = _buffer(1.5)
			var freqs := [233.08, 246.94, 349.23, 493.88, 523.25]
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				var v := 0.0
				for f in freqs:
					v += _saw(t * f * (1.0 + 0.004 * sin(t * 7.0)))
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.5)
				var env := minf(1.0, t * 80.0) * exp(-t * 2.2)
				s[i] = clampf((v / freqs.size() * 0.8 + lp * 0.35 * exp(-t * 6.0)) * env * 1.4, -1.0, 1.0)
		"suspicious":
			s = _buffer(0.45)
			for i in s.size():
				var t := float(i) / RATE
				var f := 440.0 if t < 0.16 else 587.33
				var env := minf(1.0, t * 60.0) * exp(-fmod(t, 0.16 if t < 0.16 else 1.0) * 6.0)
				s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.5 * t) * 0.2) * env * 0.55
		"crash":
			s = _buffer(0.9)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.35)
				var metal := sin(TAU * 310.0 * t) * sin(TAU * 523.0 * t) * exp(-t * 5.0)
				s[i] = clampf((lp * exp(-t * 6.0) * 1.3 + _thump(t, 0.0, 45.0) * 1.2 + metal * 0.4), -1.0, 1.0)
		"static":
			s = _buffer(0.5)
			for i in s.size():
				var t := float(i) / RATE
				var gate := 1.0 if rng.randf() > 0.15 else 0.2
				s[i] = rng.randf_range(-1, 1) * gate * 0.45 * minf(1.0, (0.5 - t) * 10.0)
		"whisper":
			s = _buffer(2.4)
			var lp := 0.0
			var bp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.08)
				bp = lerpf(bp, lp, 0.3)
				var env := sin(PI * t / 2.4) * (0.6 + 0.4 * sin(t * 9.0))
				s[i] = (lp - bp) * 3.0 * env * 0.6
		"drone":
			# 쫓길 때 깔리는 낮은 웅웅거림 (반복 재생용, 4초)
			s = _buffer(4.0)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.04)
				var beat := 0.75 + 0.25 * sin(TAU * t * 0.5)
				var v := _saw(t * 55.0) * 0.35 + _saw(t * 55.0 * 1.06) * 0.3 + sin(TAU * 27.5 * t) * 0.5 + lp * 0.6
				s[i] = v * beat * 0.45
			var wav := _to_wav(s)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = s.size()
			return wav
		_:
			s = _buffer(0.05)
	return _to_wav(s)


static func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _thump(t: float, start: float, freq: float) -> float:
	var u := t - start
	if u < 0.0:
		return 0.0
	# 내려가는 음높이의 짧은 저음
	var f := freq * (1.0 + 1.2 * exp(-u * 30.0))
	return sin(TAU * f * u) * minf(1.0, u * 400.0) * exp(-u * 16.0)


static func _saw(x: float) -> float:
	return 2.0 * (x - floor(x + 0.5))


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
