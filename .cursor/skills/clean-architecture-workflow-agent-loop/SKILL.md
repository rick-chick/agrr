---
name: clean-architecture-workflow-agent-loop
description: >-
  Cursor ローカルエージェントで clean-architecture-violation-fix-workflow の外側ループを繰り返す
  `.cursor/skills/clean-architecture-workflow-agent-loop/run.mjs` の
  終了判定・未起動時の挙動・シェルが保証しないこと（洗い出し）を説明する。
  ユーザーまたはエージェントがループ実行・バックログ不在時の挙動・「完了」の意味を確認するときに使う。
disable-model-invocation: true
---

# CA 違反修正ワークフロー（Cursor エージェントループ）

## 前提

- 実行: `.cursor/skills/clean-architecture-workflow-agent-loop/` 内で `node run.mjs`（初回は `npm install`）。
- 認証: 環境変数 `CURSOR_API_KEY` が必要（`--dry-run` 時は未設定でも可）。
- ワークフロー本文は [clean-architecture-violation-fix-workflow](../clean-architecture-violation-fix-workflow/SKILL.md) と [`ARCHITECTURE.md`](../../../ARCHITECTURE.md)。本スキルは **ループスクリプトの機械判定**だけを扱う。

## シェルが「完了」とみなしてエージェントを起動しない条件

`run.mjs` の `workflowComplete` は次のいずれかで **完了（イテレーション 0 回で終了）**。

1. **`docs/ca-violations-backlog.md` が存在しない** — リポジトリが backlog 専用ファイルに依存しない運用のとき。**これは CA 洗い出し済みを意味しない。** 自動ループだけが動かない；洗い出し・ゲートはメイン SKILL に従い手動／チャットで実施する。
2. **ファイルがあり、「## 修正単位」節の本文に未処理と判定される記述がない** — 具体的にはその節に `- [ ]`（未チェック）が無く、かつ `1. **` 形式の番号付き項目も検出されない場合。

（後方互換のため）任意で backlog ファイルを置いた場合のみ、上記 2 のパースが効く。

## パース上の注意（未完了扱いになりエージェントが回る）

- **`## 修正単位` 見出しが無い** Markdown は、正規化のため **未完了** とみなされる（ループが動く可能性がある）。
- 上記の簡易パースは **メイン SKILL の洗い出しを代替しない**。**特定文字列 grep のみで洗い出しを終えない**こと（メイン SKILL セクション0）。

## オプション

- `--max-iterations N`: 上限到達時は exit code 4（残課題の可能性）。
- `--dry-run`: エージェントを起動せずプロンプト先頭のみ表示。

## 関連

- [clean-architecture-violation-fix-workflow/SKILL.md](../clean-architecture-violation-fix-workflow/SKILL.md)
- 実装: `.cursor/skills/clean-architecture-workflow-agent-loop/run.mjs`（`workflowComplete` / `backlogHasPendingItems`）
