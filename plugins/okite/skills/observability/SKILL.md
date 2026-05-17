---
name: observability
description: エージェント自身が過去の実行・PR 履歴・CI ログ・監視データを参照するためのセルフサーブ観測スキル。「前回どうやった？」「過去 PR を見て」「CI ログを確認」「Datadog で見て」「mihari の実行履歴」など過去実行の参照が必要な依頼で発動する。エージェントが「今のセッションだけで完結する」と誤った前提を取らないよう、まず観測してから判断する作法を提供する。事実質問でも観測が必要なら発動、新規実装で過去参照が無関係な場合は使わない。
---

# observability

エージェントはセッションが切れると過去を失い、「今のコンテキストだけで完結する」前提で動きがちで、同じ失敗を繰り返したり、既存の解決策を再発明したりする。**自分の過去実行を自分で観測する作法** を共通スキルとして定義することで、判断前に過去を引き、根拠ベースで動けるようにする。OpenAI 事例で言う agent self-observability の縮図。

## 発動条件

以下のいずれかに当てはまる依頼で発動する。

- 「前回どうやった？」「過去 PR を見て」「以前の議論」「履歴を確認」などの過去参照依頼
- 「CI が落ちた」「ビルドエラー」「テストが flaky」のような失敗原因調査
- 「Datadog で確認」「メトリクス見て」「ログを引いて」のような監視データ参照
- 「mihari の実行履歴」「先週の runbook 結果」など mihari 状態の参照
- 新規実装の冒頭で「既存解決策があるか」を確認するとき
- progress-log を読んだ後、関連 PR / Issue の文脈を補強したいとき

次のケースでは使わない。

- 過去参照が無関係な完全新規実装（直接 implementation へ）
- 単純なファイル読み（直接 Read で完結）
- 観測ツール自体の設定変更（update-config が担当）

## 観測対象とアクセス手段

### GitHub（PR / Issue / Actions）

mulyu 配下では `gh` CLI ではなく **GitHub MCP ツール** を使う（環境制約）。

| 知りたいこと | 使うツール |
|---|---|
| PR 一覧・状態 | `mcp__github__list_pull_requests`, `mcp__github__search_pull_requests` |
| PR 本文・差分・コメント | `mcp__github__pull_request_read` |
| Issue 一覧・本文 | `mcp__github__list_issues`, `mcp__github__issue_read`, `mcp__github__search_issues` |
| コミット履歴 | `mcp__github__list_commits`, `mcp__github__get_commit` |
| ファイル内容（任意 ref） | `mcp__github__get_file_contents` |
| コード横断検索 | `mcp__github__search_code` |
| ワークフロー実行・CI ログ | GitHub MCP の `*workflow*` / `*run*` 系（必要に応じ ToolSearch で取得） |

ローカルブランチの状態は `git log` / `git diff` / `git status` で十分。リモート参照は MCP 経由。

### Datadog（メトリクス・ログ・モニター）

- API トークン経由（`DD_API_KEY` / `DD_APP_KEY` 環境変数）
- mihari の datadog provider が観測ロジックを持っているので、**ad-hoc な参照は curl + jq、定期観測は mihari runbook 化** を検討
- ダッシュボード URL を進捗ファイルや PR 本文に貼る運用と併用

### mihari（runbook 実行履歴）

- ローカル状態: `~/.mihari/` 配下（環境依存。リポジトリ README を確認）
- S3 同期されているなら S3 バケット
- 直近の実行: mihari CLI の `mihari logs` / `mihari status` 系（mihari リポジトリの仕様を確認）

### monban（過去の検査結果）

- ローカルで `npx @mulyu/monban all`（または `monban all --diff`）を再実行して現状把握
- CI 上の結果は GitHub Actions の workflow run ログから引く

### 進捗ファイル（progress-log）

- `.claude/progress/<task-slug>.md` を Read
- 「セッション履歴」「未解決の問い」「次の一手」を確認

## 手順

### 1. 観測目的の明確化

- 何を判断したいか / 何を再現したいかを 1 行で書く
- 「過去参照が本当に必要か」を問う。新規実装で関係ないなら observability を呼ばない

### 2. 観測対象の選択

目的別に対象を絞る:

| 目的 | 主な対象 |
|---|---|
| 過去の類似実装を探す | GitHub（search_code, list_pull_requests） |
| CI 失敗の原因調査 | GitHub Actions workflow run ログ |
| レビューでの議論を遡る | GitHub PR コメント・review |
| 監視データを引く | Datadog API |
| 自動運用の実行履歴 | mihari ログ |
| 自分の前セッションの状態 | progress-log + git log |

### 3. 観測の実行

- **絞り込みクエリを先に立てる** — 取得量が多いと context を浪費する。日付範囲・著者・キーワードで絞る
- **取得は必要最小限** — フル本文ではなく要約・タイトル一覧から始め、必要なものだけ深掘り
- **複数ソース横断** — 1 ソースで結論を出さず、GitHub と monban、PR と Issue のように 2 ソース以上で裏取り

### 4. 観測結果の記録

- 何を観測して何を判断したかを進捗ファイル・PR 本文・コミットメッセージに残す
- 「過去 PR #X で同じ問題を Y のように解決済み。今回も同じ方針を踏襲」のような形で **参照リンク付きで** 残す
- 観測結果そのものをコミットしない（古くなる）。**参照と判断だけ** 残す

### 5. 観測結果の判断への反映

- 過去解決策がある場合: それを踏襲するか、なぜ変えるかを明示
- 失敗パターンが見つかった場合: 同じ失敗を踏まない手順に組み替える
- 観測しても分からない場合: 「分からない」を進捗ファイルに記録し、ユーザに確認

## 観測クエリのレシピ

### 直近 30 日の自分の PR を引く

```
mcp__github__search_pull_requests with query "author:@me created:>2026-04-17"
```

### 特定キーワードで類似実装を探す

```
mcp__github__search_code with query "<keyword> repo:mulyu/<repo>"
```

### 失敗した CI run を引く（最新 N 件）

ToolSearch で workflow run 系ツールを取得して使う。

### Datadog のエラーログ（直近 1 時間）

```bash
curl -s -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
  "https://api.datadoghq.com/api/v2/logs/events/search" \
  -d '{"filter":{"query":"status:error","from":"now-1h","to":"now"},"page":{"limit":50}}'
```

### mihari の直近 runbook 実行

mihari リポジトリ README に従う。S3 同期されている場合は `aws s3 ls` で日時 prefix を辿る。

## 他スキルとの関係

- **progress-log** — 観測結果の記録先として最も自然。長期タスクなら必ず併用
- **implementation** — 実装ステップ 1（計画）の冒頭で observability を呼んで類似実装を探す
- **direction（okite）** — 4 軸の「運用設計」に対応する代表スキル
- **evaluator** — Evaluator に渡す材料として観測結果を提供できる

## アンチパターン

- **観測せずに「ゼロから新規実装」** → 既存解決策の再発明。冒頭で必ず類似実装を引く
- **観測結果を context に大量投入** → トークン浪費。要約・参照リンクで足りる
- **1 ソースだけで結論** → そのソースが古い・偏っている可能性。2 ソース以上で裏取り
- **観測結果そのものをコミット** → すぐ古くなる。**参照と判断** だけ残す
- **gh CLI を使おうとする** → mulyu 環境では使えない。GitHub MCP ツール経由
- **Datadog の重い全期間クエリ** → 課金とレート制限。期間・絞り込みを先に立てる
- **mihari の過去実行を観測せずに新規 runbook を書く** → 既存 runbook のパターンを取りこぼす
- **「観測しても分からなかった」を記録しない** → 次セッションで同じ観測を繰り返す。**分からなかった事実も残す**
