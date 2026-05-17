# okite

> **日本語** | [English](./README.md)

mulyu 配下リポジトリの Claude Code / monban 共通アセットを集約する場所。「掟（おきて）」= 共通ルール。

## 提供物

### 1. monban セキュリティベースライン — `monban.yml`

[monban](https://github.com/Mulyu/monban) の `extends` 機能で取り込む共通設定。secret / conflict / invisible / injection 検出、GitHub Actions ハードニング、npm サプライチェーン対策、MCP 設定検査、`.gitignore` 対象の誤コミット検出を含む。

子リポジトリの `monban.yml` で次のように継承する:

```yaml
extends:
  - type: github
    repo: Mulyu/okite
    ref: main          # 安定運用ではコミットハッシュ or タグを推奨
    path: monban.yml

# プロジェクト固有のルールはこの下に書く
```

マージ仕様:

- 配列は連結（親のルールに子のルールが追加される）
- スカラは子優先
- 推移的解決はされない（okite 側でさらに extends してもチェーンしない）

### 2. Claude Code プラグイン — `okite`

`plugins/okite/` に Claude Code プラグイン本体を置く。スキルとフックを配布する。

#### スキル

okite のスキルは「ハーネスエンジニアリングの 4 軸」（コンテキスト / 行動 / フィードバック / 運用）を判定軸に揃えて配布する。

- **thinking** — 企画・計画・設計を 3 周回（調査 → まとめ → 推敲）で深掘りする汎用スキル
- **documentation** — README / docs を日英二言語で整備するときの命名規約・言語セレクタ・同期ルール
- **implementation** — 計画を一時ドキュメントに書き出し、アーキテクチャ設計 → `monban.yml` 更新 → 実装 → テスト → `monban all` 検証 → 計画照合 → 一時ドキュメント削除 → PR の 9 ステップで進める実装プロセススキル。各ステップ終了時に 5 観点（計画一致 / スコープ / 過剰実装 / 再利用 / 安全性）でセルフレビューを挟む
- **improvement** — SKILL.md 自体を改善するメタスキル。スキル使用後のフィードバック・失敗中断・自己振り返り・明示依頼で発動し、okite プラグインスキルと呼び出し元の `.claude/skills/` の両方が対象。編集 → コミット → PR まで担当し、改修トリガーを PR 本文に必ず残す
- **direction** — okite のプロダクト方針スキル。新スキル・新フック・新ルール追加の判定軸として 4 軸（コンテキスト / 行動 / フィードバック / 運用）と中央集権適合性・既存資産での吸収可否を篩にかける
- **progress-log** — セッションを跨ぐ長期タスク用の進捗ファイル運用スキル。`.claude/progress/<task-slug>.md` に目的・受け入れ基準・フェーズ・セッション履歴・次の一手を残し、新セッションは冒頭でこれを読んで再開する
- **evaluator** — 別エージェントを起動して自分の出力を批判的にレビューさせる Generator-Evaluator 分離スキル。重大変更の PR 直前や独立観点での確認が必要なときに使う
- **observability** — エージェント自身が過去 PR・CI ログ・Datadog・mihari 実行履歴・進捗ファイルを参照するセルフサーブ観測スキル。判断前に観測する作法を提供する

#### フック

- **session-start** — Node プロジェクトで `.nvmrc` と `package.json` を見て依存をセットアップ（web 環境のみ）
- **guard-bash** — main/master への force push、`--no-verify`、`git config` 改変をブロック

プロジェクト固有の禁止事項（特定コマンドの禁止など）は各リポジトリ側で別フックとして追加する。

## 使い方

### marketplace の登録

```
/plugin marketplace add Mulyu/okite
/plugin install okite@mulyu-okite
```

または各リポジトリの `.claude/settings.json` で:

```json
{
  "extraKnownMarketplaces": {
    "mulyu-okite": {
      "source": {
        "source": "github",
        "repo": "Mulyu/okite"
      }
    }
  },
  "enabledPlugins": {
    "okite@mulyu-okite": true
  }
}
```

## バージョニング

- `ref: main` は最新版を取得（mutable、毎回 fetch）
- 安定したい場合はコミットハッシュ or タグを指定（永続キャッシュ）
- 破壊的変更時はタグを切る

## ライセンス

MIT
