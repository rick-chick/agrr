---
name: github-issue-creator
description: >-
  rick-chick/agrr 向けに GitHub issue を起票する。依頼の事実確認・議論ゲート・重複確認・
  草案提示・gh issue create・ブロッカーがなければ agent-ready 付与まで。
  issue 起票、GitHub issue 作成、バックログ起票、機能要望・バグの issue 化で適用。
  UX 監査一括起票は ux-issue-creator を使う。
disable-model-invocation: true
---

# GitHub Issue Creator（AGRR）

ユーザー依頼や調査結果を **1 件ずつ** GitHub issue に落とす。実装は **`github-issue-worker`** に委譲する（本スキルは起票まで）。

## 適用範囲

| 経路 | スキル |
|------|--------|
| 汎用（機能・バグ・リファクタ・負債） | **本スキル** |
| visual-review / CSS 監査の一括起票 | **`ux-issue-creator`** |
| 要件の深掘りのみ（起票前） | **`requirements-analysis`**（必要時） |

## 1) 依頼の理解と事実確認

起票前に次を一文ずつ言えるようにする（[`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc)）。

1. **何を issue 化するか**（対象・期待する振る舞い）
2. **根拠**（コード path、失敗テスト、再現手順、`ARCHITECTURE.md` 条項のいずれか）
3. **スコープの境界**（含めないもの）

根拠が取れない場合は **起票せず調査を続ける**（[`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc)）。推測だけで issue を書かない。

## 2) 議論ゲート（issue 前・必須）

次のいずれかに該当する場合は **`gh issue create` 前にユーザーと議論**する。`AskQuestion` が使えるときは構造化して聞く。

| 区分 | 例 | 動作 |
|------|-----|------|
| **仕様未確定** | 複数の正当な実装経路、API 形状が未定 | 選択肢・推奨・トレードオフを提示し合意を取る |
| **スコープ曖昧** | 「直して」だけ、1 issue に複数無関係タスク | 分割案を提示 |
| **規約衝突** | `ARCHITECTURE.md` 違反を前提にした依頼 | 衝突条項を示し、ADR / 規約変更が要るか確認 |
| **優先度不明** | P0 と P2 のどちらか判断不能 | 影響範囲を整理して確認 |
| **重複あいまい** | 既存 issue と部分重複（score 3–4 相当） | 新規 / コメント追記 / 統合のどれかを確認 |
| **自動実装不適** | 運用判断のみ・本番操作・権限不足 | issue 化するか、人間専用バックログにするか確認 |
| **依存未整理** | 前提 issue が未完了で着手順が不明 | 依存関係を確定 |

**議論が終わり、起票内容が確定するまで §4 以降に進まない。**

議論不要（起票へ進んでよい）の例:

- 再現手順と完了条件が書けるバグ
- ユーザーが方針・優先度・スコープを明示した機能依頼
- 調査済みで重複なし（§3）

## 3) 重複確認（必須）

```bash
gh issue list --repo rick-chick/agrr --state all \
  --search "in:title <主要キーワード>" --limit 20 --json number,title,state,labels
```

| 判定 | 動作 |
|------|------|
| 同一要求の **OPEN** issue あり | **起票しない**。既存 #N にコメントで追記 |
| **CLOSED** が `already_fixed` 相当 | 起票しない（理由を報告） |
| 部分重複 | §2 で統合方針を議論 |
| 重複なし | §4 へ |

## 4) 草案（ドライラン・必須）

`gh issue create` の**前**にチャットへ次を出力する（本文は [references/issue-body-template.md](references/issue-body-template.md) の必須セクションを満たす）。

- **タイトル**（優先度付き）
- **本文**（全文）
- **付与予定ラベル**（`bug` / `enhancement` / `documentation`）
- **`agent-ready` 付与予定**（付ける / 付けない + 理由）
- **スキップ理由**（起票しない場合）

**ユーザーが「起票して」「作成して」等と明示するまで `gh issue create` しない。**

例外: ユーザーが最初から「起票して agent-ready まで」と依頼し、§2・§3 を満たしている場合は、草案提示直後に §5 へ進んでよい。

## 5) Issue 起票

```bash
# 本文をファイルに書き出してから
gh issue create --repo rick-chick/agrr \
  --title "[P1] <要約>" \
  --label enhancement \
  --body-file /tmp/agrr-issue-body.md
```

- リポジトリは **`rick-chick/agrr`** 固定
- 本文テンプレート: [references/issue-body-template.md](references/issue-body-template.md)
- バグなら `--label bug`、ドキュメントのみなら `documentation`
- 起票後、issue 番号と URL を報告

## 6) agent-ready 付与

**起票直後**、ブロッカーがなければ `agent-ready` を付与する（ユーザーの既定意向）。これにより [`issue-worker-dispatch.yml`](../../../.github/workflows/issue-worker-dispatch.yml) 経由で **`github-issue-worker`** が実装経路に入る。

```bash
# ラベルが無ければ作成
gh label create agent-ready --repo rick-chick/agrr --color 0E8A16 --description "Ready for Issue Worker" 2>/dev/null || true
gh issue edit <N> --repo rick-chick/agrr --add-label agent-ready
```

### `agent-ready` を付け**ない**（issue はオープンのまま）

| 条件 | 理由 |
|------|------|
| ユーザーが「バックログのみ」「agent-ready は付けない」と指定 | 人間確認待ち |
| §2 の未解決項目が残っている | 仕様・方針未確定 |
| 依存 issue が未完了で実装不可 | 先に依存を閉じるか `agent-ready` を付けない |
| 調査のみ・再現不能・再現手順なし | 完了条件を満たせない |
| 実装スコープ外（運用・インフラ判断のみ等） | `out_of_scope` 想定 |
| 重複の可能性が残っている | 人間の最終確認待ち |

付けない場合は、その理由をチャットと issue コメントのどちらかに残す。

## 7) 終了条件

- [ ] §1 事実確認済み
- [ ] §2 議論ゲート通過（または議論不要と判断できる根拠あり）
- [ ] §3 重複確認済み
- [ ] §4 草案提示済み
- [ ] 起票した issue 番号・URL を報告
- [ ] `agent-ready` の有無と理由を報告

## 8) ベストプラクティス（起票品質）

1. **1 issue = 1 修正単位** — Issue Worker は 1 実行 1 issue・1 PR
2. **観測可能な完了条件** — 「改善する」ではなく「〇〇のテストが GREEN」「△△画面で□□と表示」
3. **TDD を明示** — 完了条件に `test-common` を入れる
4. **参照 path** — 調査済みファイルを `参照` に列挙（worker の着手前 triage 用）
5. **優先度はタイトル先頭** — `[P0]` > `[P1]` > `[P2]` で worker が選定しやすい
6. **実装はしない** — 起票・ラベル付与まで。コード変更は `github-issue-worker`
7. **bot 起票に倣わない** — Dependabot 等と同様、根拠のないテンプレ量産をしない

## 9) 禁止

- 根拠・完了条件のない issue 起票
- 重複確認なしの起票
- §2 を飛ばした起票（曖昧なまま `gh issue create`）
- ユーザー確認なしの `gh issue create`（§4 例外を除く）
- ブロッカーありで `agent-ready` を付与
- 本スキルで PR 作成・実装着手
- UX 監査一括を本スキルで代替（`ux-issue-creator` を使う）

## 関連

- 実装: **`github-issue-worker`**
- UX 起票: **`ux-issue-creator`** / **`ux-issue-pipeline`**
- 要件整理: **`requirements-analysis`**
- GitHub テンプレ: [`.github/ISSUE_TEMPLATE/`](../../../.github/ISSUE_TEMPLATE/)
