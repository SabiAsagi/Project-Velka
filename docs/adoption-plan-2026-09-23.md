# 이관 계획 (Adoption Plan)

> **생성일**: 2026-09-23
> **프로젝트 단계**: Production (비공식 — `stage.txt` 기록 없음; `.gd` 스크립트 31개, 씬 38개, 채워진 `data/`/`resources/`, 대화·파티 매니저·컴패니언 AI·학교 맵 및 phase1/2 검증 등 실제 동작하는 시스템으로 추정)
> **엔진**: Godot 4.7 (`/setup-engine` 실행으로 `.claude/docs/technical-preferences.md`에 반영 완료)
> **템플릿 버전**: v1.0+
> **전략**: 경량(Lightweight) 이관 — `docs/01.기획_및_시스템`부터 `docs/05.챕터1_학교`까지 기존 설계 문서(한글, 20개 파일, 주제별 통합 문서)는 템플릿의 8개 필수 섹션을 갖춘 `design/gdd/*.md` 형식으로 **마이그레이션하지 않는다**. 해당 내용은 그대로 유지되며 설계 의도의 원본(source of truth)으로 남는다. 이 계획은 템플릿의 기계적 스킬 동작에 꼭 필요하면서 비용이 적은 격차만 해소한다(엔진 설정, 단계 추적, 프로토콜 문서). GDD 기반 스킬(`/create-stories`, `/design-review`, `/review-all-gdds`, `/gate-check`의 콘텐츠 검사)은 앞으로도 `design/gdd/`에서 읽을 것이 없을 것이다 — 이는 이 전략이 감수하는 트레이드오프이며, 쫓아가야 할 버그가 아니다.

아래 항목을 순서대로 진행하세요. 완료할 때마다 체크박스를 표시하세요.
언제든 `/adopt`를 다시 실행해 남은 격차를 확인할 수 있습니다.

---

## 1단계: 차단(BLOCKING) 격차 해결 — ✅ 완료 (2026-09-23)

### 1a. technical-preferences.md에 엔진 미설정
**문제**: `project.godot`에 `config/features=PackedStringArray("4.7", "Forward Plus")`가 이미 있음에도 `.claude/docs/technical-preferences.md`의 Engine/Language/Rendering/Physics가 전부 `[TO BE CONFIGURED]` 상태였음. 엔진 전문가 라우팅을 위해 이 파일을 읽는 모든 스킬(코드 리뷰, 아키텍처 결정, 팀 스킬)이 아무 정보도 얻지 못하는 상태였음.
**조치**: `/setup-engine godot 4.7` 실행 완료
- [x] technical-preferences.md의 Engine & Language 섹션 채움

### 1b. CLAUDE.md의 깨진 @-include
**문제**: `CLAUDE.md`에 `@docs/engine-reference/godot/VERSION.md`가 포함되어 있었으나 `docs/engine-reference/` 자체가 저장소에 존재하지 않았음. 마스터 설정 파일 자체의 참조가 깨져 있던 상태.
**조치**: `/setup-engine godot 4.7` 실행으로 `docs/engine-reference/godot/VERSION.md`와 `breaking-changes.md` 생성 완료 (Godot 4.7은 2026-06-18 출시로 LLM 학습 데이터 기준일(2026-01) 이후 버전이라 MEDIUM RISK로 판단, 브레이킹 체인지 문서까지 작성함).
- [x] docs/engine-reference/godot/VERSION.md 존재
- [x] docs/engine-reference/godot/breaking-changes.md 존재

---

## 2단계: 우선순위 높음(HIGH) 격차 해결

### 2a. 공식 프로젝트 단계 없음
**문제**: `production/stage.txt`가 없음 (`production/` 디렉터리 자체가 없었음 — `production/review-mode.txt`는 이번 `/adopt` 세션에서 생성함). 단계 자동 감지는 이 프로젝트의 실제 폴더 구조(`src/`가 아닌 `scripts/`/`scenes/`)와 맞지 않는 휴리스틱에 의존할 수밖에 없음.
**조치**: 1단계 완료 후 `/gate-check production`(또는 적절한 단계 명령)을 실행해 실제 상태를 반영하는 `production/stage.txt`를 작성. 아직 에픽/스토리가 없어 정식 게이트 체크가 이르다고 느껴지면, `production`이라는 값만 담은 수동 `production/stage.txt`도 임시 조치로 허용 — 정식 게이트 체크 전까지는 "비공식"으로 표시할 것.
**예상 시간**: 5-15분
- [ ] production/stage.txt 작성

### 2b. systems-index.md 없음 (경량 버전)
**문제**: `design/gdd/systems-index.md`가 없음. 경량 전략 하에서는 이것이 전체 메커닉별 GDD 분해가 **되어서는 안 되며**, 향후 스킬 실행(과 향후 세션)이 실제 설계 콘텐츠가 어디 있는지 알 수 있도록 하는 짧은 포인터 인덱스여야 함.
**조치**: `docs/01~05` 아래 기존 문서마다 한 행씩, 대략적인 시스템 분류, 그리고 "원본: docs/0X.../[파일명].md — 템플릿 GDD 형식으로 마이그레이션되지 않음 (adoption-plan-2026-09-23.md 참고)"라는 메모를 담아 `design/gdd/systems-index.md`를 수동으로 생성. 이것은 인덱스이지 새로운 설계 작업이 아님.
**예상 시간**: 30분
- [x] design/gdd/systems-index.md를 포인터 인덱스로 생성 (2026-09-23)

### 2c. 협업 프로토콜 문서 누락
**문제**: `CLAUDE.md`의 협업 프로토콜 섹션에 "전체 프로토콜과 예시는 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` 참고"라고 되어 있으나 해당 파일이 존재하지 않음. 프로토콜(질문 → 옵션 → 결정 → 초안 → 승인, "[경로]에 써도 될까요?" 확인, 사용자 지시 없이 커밋 금지)은 현재 `CLAUDE.md`에 한 문단으로만 설명되어 있고 에이전트가 따를 수 있는 구체적 예시가 없음.
**조치**: (a) 프로토콜과 실제 예시 몇 가지를 담은 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`를 새로 작성하거나, (b) `CLAUDE.md`의 한 문단 요약이 충분하다고 판단되면 참조 링크를 제거. 이는 사용자가 직접 결정할 사안이라 일방적으로 처리하지 않고 여기 기록만 해둠.
**예상 시간**: 15분(참조 제거) ~ 30분(문서 작성)
- [ ] 결정 후 반영

---

## 3단계: 인프라 부트스트랩 (경량 전략 하에서는 보류)

표준 부트스트랩 절차(`/architecture-review` → `tr-registry.yaml`, `/create-control-manifest`, `/sprint-plan update`, `/gate-check`)는 GDD와 ADR이 이미 템플릿 형식으로 존재한다고 가정한다. 이 계획은 의도적으로 `docs/01~05`를 `design/gdd/`로 마이그레이션하지 않으므로, 지금 이 명령들을 실행하면 빈 GDD 세트를 대상으로 부트스트랩되어 거의 비어 있는 레지스트리가 만들어질 것이다.

**권장**: (a) 새로운 시스템에 대해 템플릿의 GDD/ADR 파이프라인을 실제로 사용하기 시작하거나, (b) 기존 문서의 전체/하이브리드 마이그레이션을 나중에 결정하기 전까지는 3단계를 보류할 것. 단순히 체크박스를 채우기 위해 이 명령들을 실행하지 말 것 — 아직은 유의미한 결과가 나오지 않는다.

- [ ] 새 GDD/ADR 콘텐츠가 템플릿 형식으로 작성되기 시작하면 3단계를 다시 검토

---

## 4단계: 우선순위 중간(MEDIUM) 격차

### 4a. production/ 스캐폴딩 미흡
**문제**: `production/session-state/`와 `production/session-logs/`가 없어서 `.claude/docs/context-management.md`의 파일 기반 컨텍스트 관리 전략(세션 상태 체크포인트, 압축/크래시 후 복구)이 기록할 곳이 없음.
**조치**: `production/session-state/`와 `production/session-logs/` 생성 (directory-structure.md 기준 둘 다 gitignore 대상 — `.gitignore`가 실제로 포함하는지 확인). 실제 세션 상태 추적이 시작되면 `production/session-state/active.md`에 최소 골격을 채울 것.
**예상 시간**: 10분
- [ ] production/session-state/ 및 production/session-logs/ 생성

### 4b. 과거 결정에 대한 ADR 기록 없음
**문제**: 실제 아키텍처 결정이 이미 임기응변으로 여러 번 내려졌으나(예: 커밋 `3b1ee81`의 학교 맵 하이브리드 축척 정합), `docs/architecture/`에는 ADR이 하나도 없음. 이미 만들어진 모든 결정을 소급 문서화하는 것은 경량 전략 하에서 비용 대비 가치가 낮지만, 영구히 문서화하지 않으면 향후 기술적 충돌에 대한 근거 자료가 없게 됨.
**조치**: 앞으로 중요한 기술적 선택에는 `/architecture-decision`을 사용할 것. 이미 만들어진 모든 것을 소급해서 ADR로 채우려 하지 말 것 — 사용자가 특정 과거 결정(비직관적이고 다시 논의될 가능성이 있는 경우)을 문서화하고 싶다고 명시할 때만 예외.
**예상 시간**: 필요할 때마다 지속
- [ ] 앞으로 새로운 결정에는 /architecture-decision을 사용하기로 합의

---

## 5단계: 선택적 개선 사항

### 5a. technical-preferences.md 남은 필드
**문제**: Naming Conventions는 `/setup-engine`으로 채워졌지만, Performance Budgets 중 Memory Ceiling과 Testing의 Minimum Coverage는 여전히 `[TO BE CONFIGURED]`로 남아 있음 (`/setup-engine`은 주로 Engine/Language/Rendering/Physics/Specialists/Naming/Performance/Testing framework를 채움).
**조치**: 타겟 하드웨어와 커버리지 기준이 정해지는 대로 채울 것 — 급하지 않으며, 이 시점에 억지로 답을 정하면(예: 하드웨어 확정 전 Memory Ceiling) 잘못된 값을 고정시킬 위험이 있음.
**예상 시간**: 15-30분, 기준이 정해질 때
- [ ] Memory Ceiling / Minimum Coverage 필드 검토 후 업데이트 또는 명시적으로 보류

---

## 기존 스토리에 대한 안내

`production/epics/` 아래에 아직 스토리가 없으므로 이관할 대상이 없음. 향후 템플릿의 스토리 파이프라인을 새 작업에 도입하면, 그때 생성되는 스토리는 처음부터 현재 형식을 따르게 되므로 별도 리트로핏이 필요 없음.

---

## 재실행

1~2단계 완료 후 `/adopt`를 다시 실행해 차단·우선순위 높음 격차가 해소되었는지 확인하세요. 새 실행은 프로젝트의 현재 상태를 반영합니다. 3~5단계는 우선순위가 낮으므로 원하는 속도로 진행하거나, 설계 문서 마이그레이션 전략이 바뀌면 다시 검토하면 됩니다.
