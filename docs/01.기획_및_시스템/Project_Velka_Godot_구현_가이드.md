# Project Velka Godot 구현 가이드

## 1. 문서 목적

본 문서는 《Project Velka》의 현재 Godot 프로젝트 구조와 기획 문서를 기준으로 실제 게임 구현 방향을 정의한다.

1차 개발 목표는 전체 콘텐츠 제작이 아니라 **학교 챕터를 중심으로 한 버티컬 슬라이스 완성**이다.

최종적으로 다음 플레이 흐름이 정상적으로 이어져야 한다.

> **타이틀 → 프롤로그 → 세이프 하우스 → 학교 진입 → 탐색 → 괴이 및 규칙 검증 → 탈출 → 세이프 하우스 복귀**

Godot 버전은 현재 프로젝트 설정과 동일한 **Godot 4.7 / Forward Plus**를 기준으로 한다.

---

## 2. 구현 전 저장소 정리

본격적인 구현에 들어가기 전에 저장소 내부의 **이전 버전 맵 잔재, 사용하지 않는 테스트 파일, 현재 구조와 맞지 않는 레거시 리소스**를 먼저 정리한다.

단, 무조건 삭제하지 말고 현재 씬이나 스크립트에서 참조 중인지 먼저 확인한 뒤 제거한다.

정리 대상은 다음과 같다.

- 이전 학교 맵 구현 과정에서 생성되었지만 현재 씬에서 사용하지 않는 `.tscn`
- 이전 축척 기준으로 만들어진 맵 테스트 파일
- 더 이상 사용하지 않는 Graybox/Prototype 맵
- 현재 구조로 대체된 중복 씬
- 사용되지 않는 테스트용 리소스 및 임시 Material
- 오래된 Capture/Validation 결과 파일
- 이전 구현을 위해 만들어졌으나 현재 시스템과 연결되지 않는 스크립트
- 중복된 맵 데이터 JSON
- 더 이상 참조되지 않는 PNG 오버레이 또는 임시 레퍼런스
- 개발 중 생성된 임시 파일 및 백업 파일

삭제 전 반드시 다음을 확인한다.

```text
Scene 참조
Script preload / load 참조
Autoload 참조
Resource 참조
JSON 경로 참조
Documentation 경로 참조
```

현재 실제로 사용하는 파일은 유지하고, **완전히 대체된 파일만 제거**한다.

특히 학교 맵은 현재 구조인 다음 경로를 기준으로 정리한다.

```text
scenes/school/
data/school/
scripts/school/
docs/05.챕터1_학교/
```

---

## 3. 문서명 변경 및 경로 업데이트

프로젝트 문서 이름이 변경된 경우, 코드와 다른 문서에서 참조하고 있는 **기존 파일명과 경로도 전부 최신 이름으로 변경한다.**

단순히 파일 이름만 변경하지 말고 프로젝트 전체에서 이전 이름을 검색해 참조를 함께 수정한다.

확인 대상은 다음과 같다.

- Markdown 내부 문서 링크
- 코드 주석
- JSON의 문서 경로
- Scene metadata
- Validation Script
- README 또는 개발 가이드
- Codex/AI 작업 지침
- 기타 `.md`, `.gd`, `.tscn`, `.json` 내부 문자열

예를 들어 문서명이 변경되었다면 다음과 같은 과거 이름이 프로젝트 내부에 남아 있지 않도록 한다.

```text
학교_맵_Godot_Codex_구현_가이드.md
```

문서 경로 변경 후에는 반드시 **깨진 참조가 없는지 프로젝트 전체 검색**을 진행한다.

문서명은 현재 `docs` 디렉터리의 실제 파일명을 기준으로 통일한다.

---

## 4. 학교 맵 축척 정합

학교 맵은 확정된 **하이브리드 정합 방식**을 사용한다.

기본 원칙:

**1 Godot Unit = 1m**

실제 공간 크기는 기획서의 실측 수치를 우선한다.

| 공간 | 크기 |
| --- | ---: |
| 전체 부지 | 190 × 140m |
| 운동장 | 70 × 45m |
| 본관 | 60 × 18.5m |
| 별관 | 20 × 50m |
| 체육관 | 40 × 26m |
| 기본 층고 | 3.8m |

`00_전체_배치.png`는 정확한 축척 도면이 아닌 **배치와 동선 레퍼런스**로 사용한다.

따라서 다음 항목은 PNG를 따른다.

건물의 상대적 위치와 방향, 외부 도로 형태, 출입구 방향, 산책로, 화단, 조회대, 스탠드, 구름다리 연결 구조 등이다.

반대로 PNG의 픽셀 크기와 실제 수치가 충돌할 경우 **기획서의 실측 수치를 우선한다.**

### 우선 수정 대상

현재 남아 있는 과거 PNG 절대 정합 데이터를 제거한다.

#### `data/school/phase1_site_layout.json`

- `SITE_PNG_GLOBAL_SCALE_CONFLICT` → 해결 상태로 변경
- PNG 우선이라는 과거 설명 제거
- 운동장 70×45m 고정
- 본관 중심 `(0, 11.4, -54)`
- 별관 중심 `(-60, 5.7, -1.5)`
- 체육관 중심 `(0, 4.25, 42)`

#### `SchoolMap.tscn`

- 본관, 별관, 체육관 위치 재정합
- `metadata/reference_policy`를 하이브리드 정합 기준으로 수정

#### `MainBuildingMass.tscn`

현재 PNG 기준으로 잡힌 약 80m 폭 외형을 제거하고 본관 외피를 **60×18.5m** 기준으로 변경한다.

#### `Phase1Validate.gd`

현재 PNG 크기를 정답으로 검사하는 코드를 모두 수정하고 확정 실측값을 검사하도록 변경한다.

Phase 1 Validator의 목적은 이후부터 다음과 같이 정의한다.

> PNG와 완전히 겹치는지 확인하는 도구가 아니라,  
> **실측 치수와 확정된 배치 관계가 깨지지 않았는지 검사하는 도구**

---

## 5. 권장 런타임 씬 구조

```text
SchoolMap
├─ WorldEnvironment
├─ Exterior
├─ Buildings
│  ├─ MainBuilding
│  ├─ Annex
│  └─ Gym
├─ Connections
│  └─ MainAnnexSkybridge
├─ FloorPlans
├─ Navigation
├─ Gameplay
│  ├─ PlayerParty
│  │  ├─ Sabi
│  │  └─ Shamu
│  ├─ Anomalies
│  ├─ Interactables
│  ├─ EventTriggers
│  └─ ChapterController
├─ CameraRig
├─ UI
└─ Debug
```

맵과 게임플레이 로직은 분리한다.

`Exterior`, `Buildings`, `FloorPlans`는 공간 구조를 담당하고, `Gameplay` 아래에서 플레이어, 괴이, 이벤트, 상호작용을 관리한다.

---

## 6. 사비·샤무 캐릭터 구조 리팩터링

현재처럼 하나의 `Player`에서 사비와 샤무 텍스처만 변경하는 방식은 임시 프로토타입까지만 사용한다.

실제 버티컬 슬라이스부터는 **두 캐릭터가 동시에 월드에 존재해야 한다.**

```text
PlayerParty
├─ Sabi
│  ├─ CharacterBody3D
│  ├─ Visual
│  ├─ InteractionComponent
│  ├─ StealthComponent
│  └─ CharacterState
│
└─ Shamu
   ├─ CharacterBody3D
   ├─ Visual
   ├─ InteractionComponent
   ├─ StealthComponent
   └─ CharacterState
```

두 캐릭터 모두 실제 위치, 상태, 체력, 정신력, 심박수를 따로 가진다.

플레이어가 조작 중인 캐릭터만 직접 입력을 받고, 다른 캐릭터는 Companion AI가 제어한다.

캐릭터 전환 시 캐릭터를 삭제하거나 새로 생성하지 않고 **조작 권한만 변경한다.**

---

## 7. Companion AI

1차 AI는 상태 머신 기반으로 구현한다.

```text
FOLLOW
WAIT
HIDE
ALERT
FLEE
SCRIPTED
```

사비는 회피, 은신, 단서 발견 쪽을 우선하고 샤무는 후방 경계, 플레이어 보호, 괴이 저지 행동을 우선한다.

---

## 8. 상호작용 시스템

현재의 `InteractableBase`와 `InteractionComponent` 구조는 유지하여 확장한다.

```text
DoorInteractable
ItemInteractable
DocumentInteractable
DeviceInteractable
HidingSpot
RuleEvidenceInteractable
CharacterInteractable
```

공통 상호작용 시스템을 사용하고, 캐릭터별 조건을 필요한 경우에만 추가한다.

---

## 9. 학교 내부 구현

현재 층별 PackedScene 구조는 유지한다.

### 본관

```text
Main_B1
Main_1F
Main_2F
Main_3F
Main_4F
Main_Roof
```

### 별관

```text
Annex_1F
Annex_2F
Annex_3F
```

### 체육관

```text
Gym_1F
Gym_2F
```

학교 전체는 가능하면 하나의 `SchoolMap` 안에서 실제 공간적으로 연결한다.

계단과 구름다리는 직접 이동 구조를 사용하고, 엘리베이터 등 필요한 경우에만 `FloorTransition`을 사용한다.

---

## 10. Navigation

AI 컴패니언과 괴이는 `NavigationAgent3D`를 사용한다.

```text
Navigation
├─ ExteriorRegion
├─ MainBuildingRegions
├─ AnnexRegions
├─ GymRegions
└─ ConnectionLinks
```

문, 계단, 구름다리 등의 이동 가능 여부에 따라 Navigation 연결 상태를 제어한다.

---

## 11. 괴이 시스템

현재 `AnomalyBase`를 공통 기반으로 유지한다.

```text
IDLE
PATROL
OBSERVE
INVESTIGATE
CHASE
ATTACK
LOST
SCRIPTED
```

괴이별 특수 규칙은 Component 방식으로 분리한다.

학교 버티컬 슬라이스의 핵심 조우는 다음 3종부터 구현한다.

- 세 번째 문장을 읽는 담임
- 방송실의 결석생
- 보건실의 문진표 작성자

`TrainingStalker`는 삭제하지 않고 AI 테스트용 Debug Entity로 남긴다.

---

## 12. 규칙 시스템

`RuleManager`와 `school_rules.json` 구조를 유지한다.

```text
단서 조사
↓
RuleManager.discover_rule()
↓
규칙서에 미확인 규칙 표시
↓
현장에서 규칙 검증
↓
CONFIRMED / ANOMALY / ERROR
↓
스토리 및 탈출 조건 반영
```

괴이와 이벤트는 반드시 `rule_id`로 RuleManager와 연결한다.

---

## 13. Chapter Controller

`SchoolChapterController.gd`를 추가한다.

```text
ENTER_SCHOOL
INITIAL_EXPLORATION
FIRST_RULE_DISCOVERY
CORE_INVESTIGATION
RULE_VERIFICATION
ESCAPE_CONDITION
EXIT_SCHOOL
COMPLETE
```

개별 괴이 AI가 챕터 진행을 직접 관리하지 않도록 한다.

---

## 14. HUD 및 UI

현재 `PrototypeHUD`는 기반으로 사용하되 이후 정식 HUD로 교체한다.

최소 정보:

- 활성 캐릭터
- 심박수
- 정신력
- 상호작용 프롬프트
- 위험 상태
- 상대 캐릭터 경고

규칙서는 별도 UI로 구현한다.

---

## 15. 세이브 시스템

기존 `SaveManager`를 확장한다.

추가 저장 항목:

```text
save_version
현재 챕터
챕터 진행 단계
사비 위치
샤무 위치
사비 상태
샤무 상태
활성 캐릭터
인벤토리
규칙 발견 상태
규칙 검증 상태
스토리 플래그
중요 오브젝트 상태
```

모든 오브젝트가 아니라 실제 진행에 영향을 미치는 오브젝트에만 Persistent ID를 부여한다.

---

## 16. 개발 순서

### P0 — 저장소 정리 및 데이터 정합

- 레거시 맵 파일 제거
- 미사용 씬/리소스 정리
- 문서명 변경 사항 프로젝트 전체 반영
- 깨진 경로 및 참조 수정
- 학교 하이브리드 축척 반영
- Validator 수정

### P1 — 플레이어 기반

- 사비/샤무 개별 `CharacterBody3D`
- `PlayerPartyManager`
- 캐릭터 전환
- 카메라 전환
- Companion Follow/Wait

### P2 — 학교 이동 구조

- Collision
- Navigation
- 계단
- 구름다리
- 출입구

### P3 — 코어 시스템 연결

- Interaction
- Inventory
- RuleManager
- HUD
- SaveManager

### P4 — 괴이 및 규칙

- 핵심 괴이 3종
- 규칙 검증

### P5 — 학교 챕터 완주

- 진입
- 탐색
- 규칙 검증
- 탈출
- 복귀

### P6 — 버티컬 슬라이스 완성

프롤로그 → 세이프 하우스 → 학교 → 세이프 하우스까지 정상 완주 가능 상태로 만든다.

---

## 17. 정리 작업 완료 기준

저장소 정리는 다음 조건을 만족해야 완료로 본다.

- 사용하지 않는 이전 학교 맵 씬이 남아 있지 않음
- 같은 역할을 하는 중복 씬이 없음
- 이전 축척 기준 데이터가 남아 있지 않음
- 프로젝트 내부에 존재하지 않는 문서를 가리키는 링크가 없음
- 변경 전 문서명이 코드/JSON/Markdown에 남아 있지 않음
- 삭제된 파일을 참조하는 Scene 또는 Script가 없음
- Godot 프로젝트 실행 시 Missing Resource 오류가 없음
- Phase Validation Script가 최신 설계 기준으로 PASS

---

## 18. 핵심 구현 원칙

**맵:** 실측 크기는 기획서, 배치 관계는 PNG.

**캐릭터:** 사비와 샤무는 실제 두 개체로 존재하고 조작권만 전환.

**AI:** 비조작 캐릭터와 괴이는 Navigation 기반 상태 머신.

**상호작용:** 공통 Interactable 구조 사용.

**괴이:** 추격 AI와 규칙 시스템을 결합.

**규칙서:** 탐색 결과와 실제 게임 상태를 연결.

**저장소:** 이전 구현의 잔재와 중복 파일을 남기지 않는다.

**문서:** 최신 파일명과 실제 프로젝트 경로를 항상 일치시킨다.

**개발 우선순위:** 학교 버티컬 슬라이스 완성 전에는 다른 챕터 본 제작과 멀티플레이 확장을 진행하지 않는다.
