# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7
- **Language**: GDScript
- **Version Control**: Git (GitHub: SabiAsagi/Project-Velka)
- **Build System**: Godot's built-in export presets
- **Asset Pipeline**: Godot's native resource importer; third-party CC0 packs documented in `assets/third_party/README.md`

## Project Note

### 폴더 규칙

이 저장소는 데스크톱의 `E:\Dev\Project_Velka` 폴더와 같은 구조다 (Godot 프로젝트 루트 = 저장소 루트).
게임 코드·씬·에셋은 `scripts/`, `scenes/`, `assets/`, `resources/`, `data/`, `tools/`에 두고,
자료는 아래 세 폴더 안의 기존 하위 폴더에 맞춰 정리한다. 별도의 `docs/`나 `Main_Character/` 폴더는 만들지 않는다.

- **기획서/**: 기획 문서(docx, md). 주제에 맞는 번호 폴더에 넣는다.
  `01. 기획 및 시스템` · `02. 세계관 및 설정` · `03. 캐릭터 및 개체` · `04. 맵 및 환경` ·
  `05.스토리/스토리` · `05.스토리/게임 시나리오` · `06.챕터1_학교` · `07.기술_문서`(엔진 레퍼런스 등)
  맞는 폴더가 없을 때만 같은 번호 규칙으로 새 폴더를 만든다.
- **맵 레퍼런스/**: 맵 참고 이미지. 장소별 폴더(예: `학교/`)로 정리한다.
- **캐릭터/**: 캐릭터 원본 자료. 시트는 바로 아래, `스프라이트/`·`표정/` 등 종류별 폴더로 정리한다.

파일을 옮기거나 이름을 바꾸면 `res://` 경로(.tscn, .gd, .import)와 문서·JSON의 경로 참조도 함께 고친다.

이 저장소는 이미 진행 중인 프로젝트다 (프로젝트 벨카 — Godot 2.5D 쿼터뷰 미스터리 호러).
기존 코드는 `src/`가 아니라 `scripts/`, `scenes/`, `resources/`, `data/` 구조를 쓰고,
기존 설계 문서는 `design/gdd/`가 아니라 `기획서/01. 기획 및 시스템/` 등 번호 폴더 구조를 쓴다.
이 템플릿의 경로 규칙(`src/**`, `design/gdd/**` 등)과 실제 구조가 다르므로,
`/setup-engine godot 4.7`과 `/adopt`를 먼저 실행해 실제 폴더 구조에 맞는 이관 계획을 확인한 뒤 사용할 것.

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@기획서/07.기술_문서/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

@AGENTS.md
