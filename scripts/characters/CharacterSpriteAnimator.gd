class_name CharacterSpriteAnimator
extends RefCounted

# 프로젝트 벨카 - 캐릭터 스프라이트 방향/애니메이션 해석기
# 현재 걷기 시트는 오른쪽 옆모습(side)과 오른쪽 뒷모습(back, 사비 전용)만 있으므로
# 방향별 애니메이션이 없으면 side로 대체하고, 좌우는 flip_h로 뒤집는다.
# 이후 walk_front / walk_left 등의 시트가 추가되면 자동으로 그 애니메이션을 우선 사용한다.

const FALLBACK_DIRECTION := "side"


## facing: "front" | "back" | "left" | "right"
## facing_right: 마지막 좌우 방향 (옆/뒤 시트를 뒤집을지 결정)
## is_running: 달리기(Shift) 중이면 run_ 애니메이션을 먼저 찾고, 그 방향 run_ 시트가 없으면 walk_를 speed_scale로 빠르게 튼다
static func play(sprite: AnimatedSprite3D, is_moving: bool, facing: String, facing_right: bool, speed_scale: float = 1.0,
		is_running: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim_name := ""
	if is_moving and is_running:
		for candidate in ["run_" + facing, "run_" + FALLBACK_DIRECTION]:
			# 옆모습 run 시트는 왼쪽·오른쪽 이동에만 쓴다 (앞뒤 이동은 걷기 시트를 빠르게)
			if sprite.sprite_frames.has_animation(candidate) and (candidate == "run_" + facing or facing in ["left", "right"]):
				anim_name = candidate
				speed_scale = 1.0
				break
	if anim_name == "":
		var state := "walk_" if is_moving else "idle_"
		anim_name = state + facing
		if not sprite.sprite_frames.has_animation(anim_name):
			anim_name = state + FALLBACK_DIRECTION
	# 전용 왼쪽 시트가 있으면 뒤집지 않는다.
	sprite.flip_h = not facing_right and not anim_name.ends_with("_left")
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
	sprite.speed_scale = speed_scale
