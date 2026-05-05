#!/bin/bash
# Claude Code web 環境（CLAUDE_CODE_REMOTE=true）で Node プロジェクトの依存を準備する。
# .nvmrc があれば nvm で切り替え、package.json があれば npm install を実行する。
# ローカル環境では何もしない。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -f .nvmrc ] && [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install
  nvm use
fi

if [ -f package.json ]; then
  npm install --no-audit --no-fund
fi
