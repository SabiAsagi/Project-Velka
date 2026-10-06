#!/bin/bash
# Claude Code SessionStart hook (클라우드 세션 전용): Godot 4.7 헤드리스 실행 파일 설치
# 데스크톱(Windows) 세션에서는 아무것도 하지 않는다.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7-stable"
INSTALL_DIR="$HOME/.local/godot/$GODOT_VERSION"
BIN="$INSTALL_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
LINK_DIR="$HOME/.local/bin"

if [ ! -x "$BIN" ]; then
  mkdir -p "$INSTALL_DIR"
  TMP_ZIP="$(mktemp --suffix=.zip)"
  curl -fsSL --retry 4 --retry-delay 2 -o "$TMP_ZIP" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TMP_ZIP" "$INSTALL_DIR"
  rm -f "$TMP_ZIP"
  chmod +x "$BIN"
fi

mkdir -p "$LINK_DIR"
ln -sf "$BIN" "$LINK_DIR/godot"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$LINK_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 첫 실행 시 리소스 임포트(.godot/ 캐시 생성) — 이후 헤드리스 테스트가 바로 돌아가도록
cd "${CLAUDE_PROJECT_DIR:-.}"
if [ ! -d .godot/imported ]; then
  timeout 600 "$BIN" --headless --editor --quit >/dev/null 2>&1 || true
fi

echo "Godot $("$BIN" --version 2>/dev/null) 설치됨: $LINK_DIR/godot"
