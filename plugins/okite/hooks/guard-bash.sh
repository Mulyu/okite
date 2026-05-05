#!/bin/bash
# PreToolUse(Bash) フック。汎用的に危険なシェル操作をブロックする。
# プロジェクト固有の禁止事項（npx 禁止など）は各リポジトリの .claude/hooks/ に別途置く。
set -euo pipefail

INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    process.stdout.write(j.tool_input?.command ?? "");
  } catch {
    process.stdout.write("");
  }
});
')

deny() {
  echo "[guard-bash] $1" >&2
  echo "[guard-bash] command: $CMD" >&2
  exit 2
}

if [ -z "$CMD" ]; then
  exit 0
fi

# main / master への force push を禁止
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+push'; then
  if printf '%s' "$CMD" | grep -qE '(--force([[:space:]]|=|$)|(^|[[:space:]])-f([[:space:]]|$)|--force-with-lease)'; then
    if printf '%s' "$CMD" | grep -qE '(^|[[:space:]/:])(main|master)([[:space:]]|$)'; then
      deny "Force push to main/master is forbidden."
    fi
  fi
fi

# --no-verify によるフックバイパスを禁止
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])--no-verify([[:space:]]|=|$)'; then
  deny "--no-verify is forbidden. Investigate hook failures instead of bypassing them."
fi

# git config の改変を禁止（参照系のみ許可）
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+config([[:space:]]|$)'; then
  if ! printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+config[[:space:]]+(--get|--list|-l|--show-origin|--show-scope)([[:space:]]|$)'; then
    deny "Modifying git config is forbidden in this session."
  fi
fi

exit 0
