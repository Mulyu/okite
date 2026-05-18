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

#### `deps.forbidden` の運用ルール

サプライチェーン攻撃で compromise が確認されたパッケージは `monban.yml` の `deps.forbidden.names` に追記する。エージェントが自走できるよう、メンテ手順を明文化する。

- **レビュー周期**: 半年ごとに既存リストを見直す。重大な supply chain 事象（npm レジストリでの大規模 compromise 等）が発生したときは周期を待たずに即時更新する
- **追加の流れ**: PR を経由する。`message` フィールドに事象の概要・参照 URL（advisory / 一次報道）を残す
- **削除はしない**: 既知の悪性パッケージは永続的に禁止する（後から復活しても再度通る経路にしない）
- **判断主体**: okite のメンテナが PR レビューで承認する。子リポジトリの monban.yml で個別解除が必要なら、子側で `severity` を下書きするのではなく、まず okite に追加是非を提起する

### 2. Claude Code プラグイン — `okite`

`plugins/okite/` に Claude Code プラグイン本体を置く。スキルとフックを配布する。

#### スキル

エージェントハーネスを「ハーネスエンジニアリングの 4 軸」（コンテキスト / 行動 / フィードバック / 運用）で設計・運用するためのスキル群。

- **thinking** — 企画・計画・設計を 3 周回（調査 → まとめ → 推敲）で深掘りする汎用スキル
- **documentation** — README / docs を日英二言語で整備するときの命名規約・言語セレクタ・同期ルール
- **implementation** — 計画を一時ドキュメントに書き出し、アーキテクチャ設計 → 静的検査ルール更新 → 実装 → テスト → 静的検査・テスト実行 → 計画照合 → 一時ドキュメント削除 → PR の 9 ステップで進める実装プロセススキル。各ステップ終了時に同一エージェントの軽量セルフレビュー（5 観点）を行い、重要ステップ（アーキテクチャ確定 / 大きな実装の節目 / PR 直前）では evaluator 経由のサブエージェント独立レビューを必須化する
- **improvement** — SKILL.md 自体を改善するメタスキル。スキル使用後のフィードバック・失敗中断・自己振り返り・明示依頼で発動し、プラグインスキルと呼び出し元の `.claude/skills/` の両方が対象。編集 → コミット → PR まで担当し、改修トリガーを PR 本文に必ず残す
- **direction** — エージェントハーネスのプロダクト方針スキル。新スキル・新フック・新ルール追加の判定軸として 4 軸（コンテキスト / 行動 / フィードバック / 運用）と共通化適合性・既存資産での吸収可否を篩にかける
- **progress-log** — セッションを跨ぐ長期タスク用の進捗ファイル運用スキル。`.claude/progress/<task-slug>.md` に目的・受け入れ基準・フェーズ・セッション履歴・次の一手を残し、新セッションは冒頭でこれを読んで再開する
- **evaluator** — 別エージェント（サブエージェント）を起動して自分の出力を批判的にレビューさせる Generator-Evaluator 分離スキル。implementation の重要ステップ末で必須のセルフレビュー層 2 として組み込まれる
- **observability** — エージェント自身が過去 PR・CI ログ・監視データ・自動運用ツールの実行履歴・進捗ファイルを参照するセルフサーブ観測スキル。判断前に観測する作法を提供する
- **hooks** — Claude Code のフック（`hooks.json` / `settings.json` の `hooks`）の設計指南スキル。利用可能な hook event を 4 軸にマップし、CLAUDE.md / スキル / 静的検査との棲み分け、共通ハーネスとプロジェクト固有の線引き、信頼性・性能・配布・環境変数永続化の指針、アンチパターンを集約する

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
