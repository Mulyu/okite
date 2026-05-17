---
name: hooks
description: Claude Code のフック（`hooks.json` / `settings.json` の `hooks` 節）を新設・改修するときの設計指南スキル。利用可能な hook event をハーネスエンジニアリングの 4 軸（コンテキスト / 行動 / フィードバック / 運用）にマップし、CLAUDE.md / スキル / 静的検査ルールとの棲み分け、共通ハーネスとプロジェクト固有の線引き、信頼性・性能・配布・環境変数永続化の設計指針、典型アンチパターンを集約する。「フックで X を強制したい」「これは CLAUDE.md でいいか、フックにすべきか」「PreToolUse と PostToolUse どっち？」「Stop に品質ゲートを置きたい」「nvm の効果が後続 Bash に効かない」のような設計判断・原因切り分けで発動する。Claude Code 以外のフック機構（git hooks / pre-commit 等）には使わない。事実質問・既存スクリプトの軽微修正・単発のバグ修正には使わない。
---

# hooks

フックは **エージェントの外側で決定論的に走るミドルウェア**。CLAUDE.md やスキルは「説得」、フックは「強制」。エージェントが文脈で揺れても必ず毎回起きる仕組みなので、「いつも」と「必ず」を区別できる唯一の場所である。31 種に増えた hook event の意味と適切な選択を毎回ゼロから考えると認知コストが高く、責務の置き間違い（CLAUDE.md に書くべきことをフックに、フックでやるべきことを CLAUDE.md に）が発生する。本スキルは判断軸を固定する。

## 発動条件

以下のいずれかに当てはまる依頼で発動する。

- 新フック追加・既存フック改修の設計判断
- 「これは CLAUDE.md / スキル / 静的検査 / フックのどこでやるべきか」の棲み分け判断
- どの hook event を使うかの選択判断（PreToolUse vs PostToolUse、Stop vs PostToolUse、SessionStart vs UserPromptSubmit など）
- フックが期待通り動かない原因切り分け（環境変数が後続 Bash に効かない、exit 1 でブロックしたつもりが通る、reason が Claude に伝わらない）
- direction / improvement がフック関連の改修判断を引き当てたとき

次のケースでは使わない。

- 事実質問（「PreToolUse の matcher は何が使える？」は公式ドキュメント参照で済む）
- 既存フックスクリプトの軽微なバグ修正（その場で直す）
- Claude Code 以外のフック（git hooks / pre-commit / GitHub Actions の事前チェック等）の設計

## ハーネスエンジニアリング 4 軸 × hook event

direction の 4 軸に hook event を振り分け、軸の空白を見つけてから足す。一つの event が複数軸に染み出すのは普通で、主軸を 1 つに定めて副次的染み出しを明示する。

### コンテキスト軸 — 何を見せるか

| event | 用途 |
|---|---|
| `SessionStart` | 起動・再開・clear・compact の各タイミングで branch / 直近コミット / 未コミット差分 / 進捗ファイル概要を `additionalContext` 注入 |
| `UserPromptSubmit` | プロンプト内容に応じた動的コンテキスト注入。30s タイムアウトに注意 |
| `UserPromptExpansion` | スラッシュコマンド展開時の前処理・引数バリデーション |
| `PreCompact` / `PostCompact` | 圧縮直前の保全（進捗ファイル更新の起動）、圧縮直後の補完 |
| `InstructionsLoaded` | CLAUDE.md / ルールファイル読み込みの監査 |
| `FileChanged` / `CwdChanged` | `.env` 等の変更検知 → env 再読込（`CLAUDE_ENV_FILE` 利用可） |

### 行動軸 — 何をさせ・どこまで許すか

| event | 用途 |
|---|---|
| `PreToolUse` | 実行 **前** に deny / allow / updatedInput。破壊的コマンドや危険ファイルへの書き込みを止める主役 |
| `PermissionRequest` | 権限ダイアログのカスタマイズ（auto-approve / auto-deny） |
| `PermissionDenied` | denied 後にエージェントへリトライ可否を伝える |
| `ConfigChange` | `.claude/settings.json` 改変ポリシーの強制 |
| `WorktreeCreate` | git worktree 生成のカスタマイズ |
| `SubagentStart` | サブエージェント起動の制限 |

### フィードバック軸 — 出力をどう評価・修正させるか

| event | 用途 |
|---|---|
| `PostToolUse` | ツール実行 **後** の検査・整形結果をエージェントに返す。毎回走るので重い処理は禁忌 |
| `PostToolUseFailure` | 失敗時のヒント・復旧手順を `additionalContext` で返す |
| `PostToolBatch` | 並列ツール群の結果を集約して評価 |
| `Stop` | ターン終了時の品質ゲート。1 ターン 1 回なので重い検査の置き場として最適 |
| `SubagentStop` | サブエージェントの完了基準強制 |
| `StopFailure` | API エラー（rate limit / auth）時のログ・アラート |

### 運用軸 — セッション横断でどう回すか

| event | 用途 |
|---|---|
| `SessionStart`（環境部分） | nvm / venv / direnv 等のシェル状態を `CLAUDE_ENV_FILE` に書き出して後続 Bash に渡す |
| `Setup` | `--init-only` / `--init` / `--maintenance` の 1 回限り初期化 |
| `SessionEnd` | クリーンアップ・ログ吐き出し |
| `TaskCreated` / `TaskCompleted` | TODO 命名規約・完了基準の強制 |
| `Notification` | デスクトップ通知（個人環境設定として扱う） |

## 判定フロー

新フックを足す前に必ず順に問う。

### 1. 軸の特定

- 4 軸のどこに主軸を置くかを 1 行で書く
- 副次的に染み出す軸を列挙する（「主：行動、副：フィードバック（reason をエージェントに返すので）」など）
- どの軸にも位置づけられないならフックの責務ではない可能性が高い

### 2. 既存資産での吸収可否

順に問う。

1. **CLAUDE.md / システムプロンプトの 1 行で足りるか** — 「揺れていい」ガイダンスならここで終わる。「毎回必ず」でないと困るならフック候補
2. **静的検査ルール（monban 等）で代替できるか** — 検査は事後検出、フックは事前阻止。書き込み **前** に止めたい / 実行 **前** に止めたいならフック。事後でいいなら検査ツール
3. **スキル / サブエージェントで吸収できるか** — 自発的呼び出しでよいならスキル、自発に頼ると抜けるならフック
4. ↑ すべて No / 不十分のときだけフック新設

### 3. 共通ハーネス vs プロジェクト固有

- **共通ハーネス（okite）行き**: 全プロジェクトで同じ作法（汎用 destructive ガード、シークレットファイル書き込み禁止、git context 注入）
- **プロジェクト固有（各リポ `.claude/hooks/`）行き**: 言語 / ツール固有のコマンド禁止（`npx` 禁止等）、プロジェクト固有の品質ゲート（`npm run lint`、`monban all --diff`）、ドメイン固有のコンテキスト注入

「3 プロジェクトで似たフックが現れたら共通化を検討」「1 プロジェクト固有の判断を共通に上げない」は direction と同じ。

### 4. event の選択

同じ目的に複数 event が当てはまるとき、次の判断軸で選ぶ。

| 比較 | 選び方 |
|---|---|
| `PreToolUse` vs `PostToolUse` | 止めたい→ Pre、検査結果を返したい→ Post |
| `PostToolUse` vs `Stop` | 毎編集の即時 feedback→ Post、ターン末一括の重い検査→ Stop。**毎編集での重い検査は侵襲的で体感を破壊する**（過去判断あり） |
| `SessionStart` vs `UserPromptSubmit` | 起動 1 回の固定コンテキスト→ SessionStart、プロンプト内容依存の動的コンテキスト→ UserPromptSubmit（30s タイムアウト注意） |
| `Stop` vs `SubagentStop` | メインエージェントのターン末→ Stop、サブエージェント単位→ SubagentStop |

## 設計指針

### 信頼性

- **exit code 規律**: `0` 成功、`2` ブロック、その他は非ブロック。**`exit 1` はブロックされない**ので「止めたつもり」の典型バグ。確実に止めたいなら `exit 2` か `hookSpecificOutput.permissionDecision: "deny"`
- **構造化出力を使う**: `hookSpecificOutput.permissionDecisionReason` で reason を返すと Claude の context に渡る。stderr 一行 deny では「なぜ止まったか」が伝わらず無駄なリトライを誘発する
- **fail-closed の方向を意識**: パース失敗・前提コマンド欠如のときに「素通り」になっていないか確認。汎用ガードは fail-closed（疑わしきは deny）に倒す

### 性能

- `SessionStart` は **<1 秒** を目標（毎セッション同期実行）
- `UserPromptSubmit` のタイムアウト既定は **30 秒**（他の event は 600 秒）。重い処理は載せない
- `PostToolUse` で **+500ms** を超える処理は体感を悪化させる。重い検査は `Stop` に寄せる
- 不要な発火を `matcher` と `if` 条件で削る（`if: "Bash(rm *)"`、`if: "Edit(*.ts)"` 等）

### 依存

- **配布側フック**（`${CLAUDE_PLUGIN_ROOT}`）は特定言語ランタイムに依存しない。`jq` か pure shell で完結させる。Node / Python 等を要求すると入っていない環境で fail-closed
- **プロジェクト側フック**（`${CLAUDE_PROJECT_DIR}`）はそのプロジェクトの言語前提に乗ってよい

### 配布

- 配布側スクリプトの参照は `${CLAUDE_PLUGIN_ROOT}/hooks/...`
- プロジェクト側スクリプトは `${CLAUDE_PROJECT_DIR}/.claude/hooks/...`
- 配布側と各プロジェクトで同じ event に複数フックが登録されると **全部走る**（早期 deny がなければ）。重複・順序を意識する

### 環境変数永続化

- `SessionStart` / `Setup` / `CwdChanged` / `FileChanged` でのみ `CLAUDE_ENV_FILE` が使える
- `nvm use` や `direnv export` の効果を **後続 Bash に渡す** には `$CLAUDE_ENV_FILE` に `export PATH=...` を追記する。hook 内サブシェルで `nvm use` を呼ぶだけでは消える（典型バグ）

### 観測

- `systemMessage` でユーザに重要決定を可視化
- `additionalContext` でエージェントに判断材料を返す
- `suppressOutput: true` でノイズを debug log に閉じる

## アンチパターン

- **侵襲的 PostToolUse** — 毎編集で `npm test` や `monban all` を走らせ、体感を破壊する。「PostToolUse で `monban all` 自動実行」は過去に明示的に却下されている。重い検査は `Stop` に置くか、明示実行 / CI に任せる
- **`exit 1` でブロックしたつもり** — 非ブロック扱い。`exit 2` か JSON 出力の `permissionDecision: "deny"` を使う
- **フックで「説得」** — CLAUDE.md やスキルでやるべきガイダンスをフックに押し込み、ユーザ操作の柔軟性を奪う。「揺れていい」ものはフックにしない
- **CLAUDE.md で「強制」** — 「毎回必ず」を CLAUDE.md / システムプロンプトに書くだけ。確率的に従われない。決定論を求めるならフックへ
- **過剰共通化** — プロジェクト固有のコマンド禁止を共通フックに昇格。各プロジェクトが回避できなくなる。「3 プロジェクトで現れたら共通化」を待つ
- **stderr deny / reason 空** — Claude に「なぜ止まったか」が伝わらず、リトライ判断ができない。`permissionDecisionReason` を必ず返す
- **配布側フックのランタイム依存** — Node / Python に依存して fail-closed を誘発。`jq` か pure shell で完結させる
- **`SessionStart` の重さ** — API 呼び出しや重い git 操作で起動が遅くなる。`git log -5 --oneline` 程度に留め、重い観測は observability スキルへ
- **`CLAUDE_ENV_FILE` 不使用** — `nvm use` / `direnv` 等の効果が hook 内サブシェルに閉じる。`$CLAUDE_ENV_FILE` 経由で後続 Bash に渡す
- **検査の二重実装** — monban の検査とフックで同じ条件を両方持ち、メンテが二重化。検出は monban、阻止はフック、と役割を分ける
- **`disableAllHooks: true` で局所的に逃げる** — フックが期待通り動かないときの原因切り分けを諦めて全体無効化。本スキルの「判定フロー → event の選択」「設計指針」を遡って原因を絞る

## 他スキルとの関係

- **direction** — 「フック化すべきか / 共通ハーネスかプロジェクト固有か」の上位判断は direction の 4 軸判定。本スキルは「フック化が決まったあとの設計指南」
- **improvement** — フックスクリプトや `hooks.json` の改修手続きは improvement の流れ（振り返り → 改修案 → 編集 → PR）に乗る。本スキルは改修判断の中で参照される
- **implementation** — 新フック追加を実装作業として進めるときは implementation の 9 ステップ。本スキルは「やるべきか・どう設計するか」を決める前段
- **observability** — フック実行結果（exit / additionalContext / systemMessage）の振り返りで参照
- **monban の `agent.settings` / `agent.mcp`** — `.claude/settings.json` 上の `hooks` フィールド / MCP 設定の危険検査と相補。本スキルは「フックが何を止めるか」の設計、monban は「設定そのものの危険」の検査
