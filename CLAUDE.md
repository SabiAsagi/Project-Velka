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

이 저장소는 이미 진행 중인 프로젝트다 (프로젝트 벨카 — Godot 2.5D 쿼터뷰 미스터리 호러).
기존 코드는 `src/`가 아니라 `scripts/`, `scenes/`, `resources/`, `data/` 구조를 쓰고,
기존 설계 문서는 `design/gdd/`가 아니라 `docs/01.기획_및_시스템/` 등 번호 폴더 구조를 쓴다.
이 템플릿의 경로 규칙(`src/**`, `design/gdd/**` 등)과 실제 구조가 다르므로,
`/setup-engine godot 4.7`과 `/adopt`를 먼저 실행해 실제 폴더 구조에 맞는 이관 계획을 확인한 뒤 사용할 것.

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

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
