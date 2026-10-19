class_name HackDifficulty
extends RefCounted

## 해킹의 조정 가능한 값은 공통 데이터에서 읽는다. 장면의 명시 설정이 우선한다.
const PATH := "res://data/hacking/difficulty.json"
static var _data: Dictionary = {}

static func config() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert(parsed is Dictionary, "해킹 난이도 데이터를 읽을 수 없습니다: " + PATH)
		_data = parsed
	return _data

static func profile(tier: int) -> Dictionary:
	return config()["tiers"][clampi(tier, 0, 2)]

static func terminal_settings(kind: String, tier: int) -> Dictionary:
	var values := profile(tier)
	var dimensions: Array = values["circuit_size"]
	var size := Vector2i(int(dimensions[0]), int(dimensions[1])) if kind == "circuit" else Vector2i(int(values["tries"]), 0)
	if kind == "frames":
		size = Vector2i(7, 0)
	return {"size": size, "trace": float(values.get(kind + "_trace", values["circuit_trace"]))}
