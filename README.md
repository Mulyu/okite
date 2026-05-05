# okite

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

- **thinking** — 企画・計画・設計を 3 周回（調査 → まとめ → 推敲）で深掘りする汎用スキル
- **docker** — Claude Code web 環境で Docker デーモンを起動するときの制約と手順

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
