class_name CharacterSpriteAnimator
extends RefCounted

# 프로젝트 벨카 - 캐릭터 스프라이트 방향/애니메이션 해석기
# 현재 걷기 시트는 오른쪽 옆모습(side)과 오른쪽 뒷모습(back, 사비 전용)만 있으므로
# 방향별 애니메이션이 없으면 side로 대체하고, 좌우는 flip_h로 뒤집는다.
# 이후 walk_front / walk_left 등의 시트가 추가되면 자동으로 그 애니메이션을 우선 사용한다.

const FALLBACK_DIRECTION := "side"


## facing: "front" | "back" | "left" | "right"
## facing_right: 마지막 좌우 방향 (옆/뒤 시트를 뒤집을지 결정)
static func play(sprite: AnimatedSprite3D, is_moving: bool, facing: String, facing_right: bool, speed_scale: float = 1.0) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var state := "walk_" if is_moving else "idle_"
	var anim_name := state + facing
	if not sprite.sprite_frames.has_animation(anim_name):
		anim_name = state + FALLBACK_DIRECTION
	# 전용 왼쪽 시트가 있으면 뒤집지 않는다.
	sprite.flip_h = not facing_right and not anim_name.ends_with("_left")
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
	sprite.speed_scale = speed_scale
