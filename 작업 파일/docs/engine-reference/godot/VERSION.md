# Godot — 버전 레퍼런스

| 항목 | 값 |
|------|-----|
| **엔진 버전** | Godot 4.7 |
| **프로젝트 고정일** | 2026-09-23 |
| **정식 출시일** | 2026-06-18 |
| **LLM 학습 데이터 기준일** | 2026-01 |
| **위험도** | MEDIUM — 학습 데이터 기준일 이후 출시된 버전 |
| **최종 문서 검증일** | 2026-09-23 |

## 참고

Godot 4.7은 이 세션의 LLM 학습 데이터 기준일(2026년 1월) 이후인 2026년 6월 18일에 정식 출시되었다.
공식 문서는 4.6 → 4.7 업그레이드가 대부분의 프로젝트에 "비교적 안전(relatively safe)"하다고 설명하지만,
동작 변경(behavior change)과 기본값 변경이 다수 존재하므로 API를 추천하기 전에 항상
`breaking-changes.md`를 먼저 확인해야 한다.

이 프로젝트(프로젝트 벨카)는 다음을 사용한다:
- `CharacterBody3D` 기반 3D 캐릭터 이동 (Jolt 물리 엔진이 아닌 기본 Godot Physics 사용 — `project.godot`에 `physics_engine` 오버라이드 없음 확인됨)
- `RichTextLabel` (대사창 `scripts/ui/DialogueBox.gd`) — 단, `add_image`/`update_image` 등 API 시그니처가 변경된 메서드는 현재 호출하지 않음

## 다음 확인 사항

에이전트가 다음 영역의 코드를 제안하기 전에는 `breaking-changes.md`를 반드시 확인할 것:
- GDScript 타입 반환값 관련 코드
- `RichTextLabel` 이미지 삽입 관련 코드 (API 시그니처 변경됨)
- `AudioStreamPlayer` 관련 코드 (`area_mask` 기본값 변경)
- `CanvasItem` 라인 드로잉 관련 코드 (안티에일리어싱 페더 제거)
- 애니메이션 `LookAtModifier3D` 관련 코드 (`relative` 기본값 변경)

불확실한 API는 WebSearch로 재검증할 것.

`/setup-engine refresh`로 언제든 이 문서를 최신 상태로 갱신할 수 있다.
