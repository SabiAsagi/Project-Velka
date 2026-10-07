class_name FacingResolver
extends RefCounted

# 프로젝트 벨카 - 캐릭터가 바라보는 방향(front/back/left/right) 결정기
# 대각선 이동에서는 좌우 성분과 앞뒤 성분이 거의 같아서, 단순히 큰 쪽을 고르면
# 옆모습·뒷모습 시트가 프레임마다 번갈아 바뀐다. 이를 막기 위해
#   1) 한쪽 성분이 AXIS_DOMINANCE 배 이상 클 때만 그 축으로 바꾸고 (그 사이는 지금 방향 유지)
#   2) 새 방향이 SWITCH_DELAY 초 이상 이어질 때만 실제로 바꾼다 (키를 떼는 순간의 한두 프레임 무시).
# 8방향 시트가 생기면 이 클래스에 대각선 방향을 추가한다.

## 이 배수 이상 차이가 나야 그 축 방향으로 본다 (1.3 ≈ 대각선에서 ±7.5° 범위는 유지)
const AXIS_DOMINANCE := 1.3
## 새 방향이 이 시간(초) 이상 유지돼야 바꾼다
const SWITCH_DELAY := 0.08

var facing: String = "front"
## 마지막 좌우 방향 (옆/뒤 시트를 뒤집을지 결정)
var facing_right: bool = true

var _pending_key: String = ""
var _pending_time: float = 0.0


## right_amount: 화면 오른쪽 성분, toward_camera: 화면 아래(카메라 쪽) 성분.
## immediate: 멈춰 있다가 출발할 때처럼 지연 없이 바로 바꿀 때 true.
func update(right_amount: float, toward_camera: float, delta: float, immediate: bool = false) -> String:
	if Vector2(right_amount, toward_camera).length() < 0.05:
		_pending_key = ""
		return facing
	var next_facing := _candidate(right_amount, toward_camera)
	var next_right := facing_right
	if absf(right_amount) > 0.1:
		next_right = right_amount > 0.0
	if next_facing == facing and next_right == facing_right:
		_pending_key = ""
		return facing
	var key := next_facing + ("R" if next_right else "L")
	if immediate:
		_apply(next_facing, next_right)
		return facing
	if key != _pending_key:
		_pending_key = key
		_pending_time = 0.0
	_pending_time += delta
	if _pending_time >= SWITCH_DELAY:
		_apply(next_facing, next_right)
	return facing


func _candidate(right_amount: float, toward_camera: float) -> String:
	var side := "right" if right_amount > 0.0 else "left"
	var vertical := "front" if toward_camera > 0.0 else "back"
	if absf(right_amount) > absf(toward_camera) * AXIS_DOMINANCE:
		return side
	if absf(toward_camera) > absf(right_amount) * AXIS_DOMINANCE:
		return vertical
	# 대각선: 지금 방향이 두 성분 중 하나면 그대로, 아니면 옆모습(양쪽 시트가 다 있다)
	if facing == side or facing == vertical:
		return facing
	return side


func _apply(next_facing: String, next_right: bool) -> void:
	facing = next_facing
	facing_right = next_right
	_pending_key = ""
