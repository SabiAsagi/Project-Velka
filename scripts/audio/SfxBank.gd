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
#   bell      : 학교 종 (딩-동-댕-동)
#   siren     : 공장 경보 사이렌 (반복)
#   breath    : 숨이 차서 헐떡이는 소리 (들숨·날숨 세 번)
#   hit       : 둔탁하게 치는 소리 + 젖은 것이 뒤틀리는 소리 (개체를 쳤을 때)

const RATE := 22050
## 시작할 때 백그라운드에서 미리 합성해 두는 소리 (처음 쓸 때 메인 스레드가 멈추지 않게 한다)
## 합성이 오래 걸리는 것(bell 약 125ms, sting 45ms, drone 44ms)을 앞에 둔다.
const PREWARM_NAMES := ["bell", "sting", "drone", "siren", "whisper", "breath", "crash", "heartbeat", "hit",
	"suspicious", "static", "footstep"]

static var _cache: Dictionary = {}
## _cache 는 메인 스레드와 미리 합성하는 작업 스레드가 함께 쓰므로 뮤텍스로 감싼다
static var _mutex := Mutex.new()
static var _prewarm_started: bool = false
static var _prewarm_task_id: int = -1
static var _prewarm_done: bool = false


## 받은 소리를 반환한다. 아직 없으면 그 자리에서 합성한다 (스레드 안전).
static func stream(sfx_name: String) -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _cache.get(sfx_name)
	_mutex.unlock()
	if cached != null:
		return cached
	var made := _make(sfx_name) # 오래 걸리는 합성은 뮤텍스 밖에서 한다
	_mutex.lock()
	if _cache.has(sfx_name):
		made = _cache[sfx_name] # 그 사이 다른 스레드가 먼저 만들었으면 그것을 쓴다
	else:
		_cache[sfx_name] = made
	_mutex.unlock()
	return made


## 모든 소리를 WorkerThreadPool 작업 하나로 미리 합성한다. 여러 번 불러도 한 번만 시작한다.
## 합성 도중 stream() 이 먼저 불려도 안전하다 (그 소리만 그 자리에서 만든다).
static func prewarm() -> void:
	if _prewarm_started:
		return
	_prewarm_started = true
	_prewarm_task_id = WorkerThreadPool.add_task(_prewarm_all, false, "SfxBank prewarm")


## 미리 합성이 끝났는지. 끝났으면 작업 스레드 정리도 같이 한다 (WorkerThreadPool 작업은 한 번 기다려 줘야 해제된다).
static func is_prewarmed() -> bool:
	_mutex.lock()
	var done := _prewarm_done
	_mutex.unlock()
	if done:
		wait_prewarm() # 이미 끝났으므로 바로 돌아온다
	return done


## 미리 합성이 끝날 때까지 기다린다 (테스트·종료 처리용, 게임 중에는 부르지 않는다)
static func wait_prewarm() -> void:
	if _prewarm_task_id >= 0:
		var task_id := _prewarm_task_id
		_prewarm_task_id = -1
		WorkerThreadPool.wait_for_task_completion(task_id)


static func _prewarm_all() -> void:
	for sfx_name in PREWARM_NAMES:
		stream(sfx_name)
	_mutex.lock()
	_prewarm_done = true
	_mutex.unlock()


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
		"bell":
			# 학교 종 (딩-동-댕-동). 음이 아주 조금 어긋나 있다.
			s = _buffer(4.2)
			var notes := [659.25, 523.25, 587.33, 392.0]
			for i in s.size():
				var t := float(i) / RATE
				var v := 0.0
				for n in notes.size():
					var u := t - n * 0.62
					if u < 0.0:
						continue
					var f: float = notes[n] * (1.0 - 0.006 * n)
					var env := minf(1.0, u * 300.0) * exp(-u * 1.5)
					v += (sin(TAU * f * u) + 0.4 * sin(TAU * f * 2.76 * u) * exp(-u * 4.0) + 0.25 * sin(TAU * f * 5.4 * u) * exp(-u * 9.0)) * env
				s[i] = clampf(v * 0.32, -1.0, 1.0)
		"hit":
			s = _buffer(0.55)
			var lp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.3)
				var thud := _thump(t, 0.0, 62.0) * 1.3
				var crack := lp * exp(-t * 40.0) * 0.9
				# 뒤틀리며 되돌아가는 낮은 꾸르륵 (조금 늦게)
				var u := t - 0.12
				var squelch := 0.0
				if u > 0.0:
					squelch = sin(TAU * (90.0 + 60.0 * sin(u * 38.0)) * u) * exp(-u * 7.0) * 0.45
				s[i] = clampf(thud + crack + squelch, -1.0, 1.0)
		"breath":
			# 헐떡임: 걸러낸 잡음을 짧은 들숨·긴 날숨 세 쌍으로 끊는다
			s = _buffer(2.1)
			var lp := 0.0
			var bp := 0.0
			for i in s.size():
				var t := float(i) / RATE
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.22)
				bp = lerpf(bp, lp, 0.12)
				var u := fmod(t, 0.7)
				var env := 0.0
				if u < 0.22:
					env = sin(PI * u / 0.22) * 0.7
				elif u < 0.62:
					env = sin(PI * (u - 0.22) / 0.4)
				env *= 1.0 - t / 2.6
				s[i] = (lp - bp) * 2.4 * env * 0.7
		"siren":
			# 공장 경보 사이렌 (오르내리는 소리, 반복 재생용 2초)
			s = _buffer(2.0)
			var phase := 0.0
			for i in s.size():
				var t := float(i) / RATE
				var f := 620.0 + 360.0 * (0.5 - 0.5 * cos(TAU * t / 2.0))
				phase += TAU * f / RATE
				var v := sin(phase) * 0.55 + _saw(phase / TAU) * 0.25
				s[i] = v * 0.42
			var siren := _to_wav(s)
			siren.loop_mode = AudioStreamWAV.LOOP_FORWARD
			siren.loop_begin = 0
			siren.loop_end = s.size()
			return siren
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
