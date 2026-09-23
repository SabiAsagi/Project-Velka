# Godot 4.6 → 4.7 호환성 깨짐(Breaking Changes) 목록

> 최종 검증일: 2026-09-23
> 출처: [공식 마이그레이션 가이드](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html), [Godot 4.7 릴리스 노트](https://godotengine.org/releases/4.7/)

이 프로젝트(Godot 4.7, GDScript, CharacterBody3D 기반 2.5D 쿼터뷰)에 실제로 영향을 줄 가능성이 있는
항목은 **★ 표시**했다.

## 1. GDScript

- 패킹 배열(PackedArray) 요소를 직접 대입할 때 전체 속성의 세터(setter)가 더 이상 호출되지 않음
- ★ 반환 타입이 지정된 함수에서 상속받은 경우, 이제 명시적인 `return` 문(`return null` 포함)이 필요함 — 정적 타입 검사가 엄격해졌으므로 새 함수 작성 시 항상 명시적 return을 넣을 것

## 2. 3D

- `CPUParticles3D`/`GPUParticles3D`의 `request_particles_process`에 `process_time_residual` 선택 매개변수 추가 (하위 호환)
- `PhysicsServer2DExtension._body_set_shape_as_one_way_collision`에 `direction` 매개변수 추가
- **Jolt Physics 사용 시에만 해당** (이 프로젝트는 기본 Godot Physics 사용 — 해당 없음):
  - `WorldBoundaryShape3D` 평면 거리 부호 반전
  - `SoftBody3D` 기본 질량 0 → 1kg
  - `SoftBody3D.linear_stiffness` 적용 방식 변경
  - `Area3D`가 `SoftBody3D` 겹침을 감지하기 시작

## 3. 2D

- `CPUParticles2D`/`GPUParticles2D`도 3D와 동일하게 `process_time_residual` 매개변수 추가
- ★ `AudioStreamPlayer`의 기본 `area_mask`: `1` → `0` — 오디오 버스 오버라이드를 사용하는 사운드가 있다면 마이그레이션 후 동작 확인 필요 (프로젝트에 `default_bus_layout.tres` 존재 — 확인 권장)
- `CanvasItem` 라인 드로잉의 안티에일리어싱 페더가 제거되어 선이 더 얇게 보일 수 있음

## 4. UI / Control

- ★ `RichTextLabel.add_image`/`update_image` 메서드 시그니처 변경: `width`/`height`가 `int`→`float`, `width_in_percent`/`height_in_percent`(`bool`)가 `width_unit`/`height_unit`(`RichTextLabel.ImageUnit` enum)으로 대체됨 — **`scripts/ui/DialogueBox.gd`는 현재 이 메서드들을 호출하지 않아 영향 없음. 이미지 삽입 기능을 대사창에 추가할 계획이 있다면 새 시그니처를 사용할 것**
- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`로 이름 변경
- `Control.accessibility_live` 속성 타입 변경: `DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode`
- 기본값 변경: 스트레치 모드 `disabled`→`canvas_items`, 스트레치 종횡비 `keep`→`expand` — 프로젝트의 뷰포트 스케일링 설정을 확인할 것

## 5. 셰이더

- `LinearToSRGB` 비주얼 셰이더 노드: Mobile/Forward+ 렌더러에서 `[0.0, 1.0]` 범위 클램핑이 제거됨 — ★ 이 프로젝트는 Forward+ 렌더러를 사용하므로, 해당 노드를 쓰는 커스텀 셰이더가 있다면 결과값 확인 필요

## 6. 입력

- 마우스/키보드 디바이스 ID 기본값: `0` → `InputEvent.DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD` — 여러 입력 장치를 구분하는 코드가 있다면 확인 필요 (현재 프로젝트에는 해당 코드 없음)

## 7. 애니메이션

- `LookAtModifier3D.relative` 기본값: `true` → `false`

## 8. 코어/오디오

- `Animation.length` 타입 메타데이터: `float` → `double`
- `OptimizedTranslation.generate` 반환 타입: `void` → `bool`
- `AudioEffectSpectrumAnalyzer.tap_back_pos` 속성 제거

## 결론

이 프로젝트에 실질적으로 영향을 줄 수 있는 항목은 GDScript 명시적 return, `AudioStreamPlayer.area_mask`
기본값 변경, Forward+ 렌더러의 `LinearToSRGB` 클램핑 제거 세 가지다. Jolt 관련 변경사항은 이 프로젝트와
무관하다 (기본 Godot Physics 사용 확인됨). 실제 엔진 업그레이드 전 오디오 버스 동작과 커스텀 셰이더
결과를 육안으로 확인할 것을 권장한다.
