# References ファイル作成ガイド

各スキルの `references/` 配下に置く補助資料の作り方。SKILL.md と references が**互いの劣化コピーにならない**ことを最優先とする。

## 基本方針（重複排除）

- **情報源は 1 つに集約**。同じテンプレ・ルールを SKILL.md と references の両方に書かない。
- **テンプレ・コード例**: 短くて 1 個で済むなら **SKILL.md 本文**に置く。CRUD フル例・複数バッキング・Controller 統合まで含めて長くなるなら **`references/TEMPLATE.md`** に切り出し、SKILL.md からはリンクのみ。
- **ルール**: 簡潔ルールは SKILL.md 本文の「## ルール」に。HTTP ステータス表・命名表・例外抽出ヘルパ等の付録は **`references/RULES.md`**。
- **命名規則**: 一覧表は **`references/NAMING.md`** に集約。
- 用語・原則の長文化は避け、`ARCHITECTURE.md` や [`agent-conventions.mdc`](../../rules/agent-conventions.mdc) など**所在ファイルへリンク**する。

## 配置

```
skill-name/
├── SKILL.md
├── scripts/          # スキル専用の実行スクリプト（任意）
└── references/
    ├── TEMPLATE.md   # 長尺テンプレが必要なときのみ
    ├── RULES.md      # 付録ルール
    └── NAMING.md     # 命名表
```

- **スキル用スクリプトはスキル以下へ**。`.cursor/skills/<skill-name>/scripts/` に置き、SKILL.md からは `.cursor/skills/<skill-name>/scripts/<file>` で参照する。リポジトリ直下の `scripts/` にスキル専用スクリプトを増やさない（共有の本番・CI 用は [`scripts/`](../../../scripts/) に残す。例: [`dev-docker`](../dev-docker/SKILL.md)、[`gcp-test-local`](../gcp-test-local/SKILL.md)）。
- 1 階層まで。`references/sub/...` は作らない。
- `IMPLEMENTATION.md` と `TEMPLATE.md` のような **同じコードを 2 ファイルに分割しない**（過去の整理で全削除済）。

## SKILL.md の構成テンプレ（推奨）

```markdown
---
name: <skill-name>
description: <一文。Use when ... を含める>
disable-model-invocation: <true|false>
---

# <タイトル>

## When to Use
- <発火条件・トリガ語>

## Instructions
- <数行で要点>。詳細・命名は References を参照。

## 用語 / ディレクトリ / テンプレート / ルール
（必要なものだけ。冗長な目次・「## 参照の使い方（階層）」表は書かない）

## References
- [references/TEMPLATE.md](references/TEMPLATE.md) — <一行説明>
- [references/RULES.md](references/RULES.md) — <一行説明>
- [references/NAMING.md](references/NAMING.md) — <一行説明>
- 関連スキル・ARCHITECTURE.md などへのリンク
```

## やってはいけない

- **同じリストを「## Instructions」「## References」「## 参照（階層）」に 2〜3 回書く**（読み手の認知コストを増やすだけ）。
- **`## 参照の使い方（階層）` テーブル**（「本 SKILL = ルール、references = 詳細」）の定型ボイラープレート。情報量が無いので書かない。
- **`When to Use` と frontmatter `description` の二重記述**。`description` で済む内容は本文に再掲しない。
- **`references/IMPLEMENTATION.md` と `references/TEMPLATE.md` の二重テンプレ**。どちらか 1 つに集約する。
- **ARCHITECTURE.md と矛盾する例**（`rescue StandardError => e; on_failure(e.message)` 等）。SKILL も references も `mandatory-scan.md` のスキャン対象であることを忘れない。

## 移行・更新時の心得

- 既存 SKILL/references を編集するときは、**まず重複を 1 か所に集約**してから加筆する。
- `references/RULES.md` を 100 行超に膨らませた節（「メトリクス」「パフォーマンスルール」など、適用根拠が薄い節）は削る。
- 命名のサンプル一覧は `NAMING.md` に集める（散らさない）。
