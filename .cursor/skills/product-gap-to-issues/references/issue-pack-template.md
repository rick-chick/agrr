# Issue パックテンプレート

起票前に `tmp/product-gap/issue-pack.md` にまとめる。本文は [`github-issue-creator/references/issue-body-template.md`](../../github-issue-creator/references/issue-body-template.md) に合わせる。

---

## 方針（enhancement-plan.md）

```markdown
# 方針: <テーマ名>

## 方針一言
<採用案の要約>

## 画面役割

| 画面 | 役割 | v1で足す | 足さない |
|------|------|----------|----------|
| | | | |

## ユーザーセグメント（テーマに関係する場合）

| セグメント | 主に効く画面 |
|------------|--------------|
| | |

## v1 / v2

（`theme-selection.md` の幅 vs 深さ判定と整合すること）

### v1（起票する）
1. …

### v2（起票しない・Epic に列挙のみ）
- …

## スコープ外
- …

## 新規画面を含む場合
- new_surface_justification: …

## 集約 API・新ルートの観測
- リソース上限: …
- 想定 API 呼び出し: …
- 新ルート要否: …
- 集約 API 要否: …

## 当初案 → 採用案

| 当初案 | 採用案 |
|--------|--------|
| | |
```

---

## Epic

**タイトル:** `[P1][UX][epic] <テーマ要約>`

**ラベル:** `enhancement`（`epic` ラベルが無ければタイトルの `[epic]` のみ）

**参照の制約** — issue 本文の「参照」節に `tmp/product-gap/` path は**禁止**（成果物は commit しないため観測不能）。許可する参照は次のみ:

- リポジトリ内のコード path（例: `frontend/src/app/...`, `crates/agrr-domain/...`）
- 関連 GitHub issue / PR 番号（`#N`）

```markdown
## 目的
<2–4行>

## スコープ外
- …

## 子 issue（v1）
- [ ] CHILD_1 <タイトル>
- [ ] CHILD_2 …

## 子 issue（v2・後続）
- …

## 完了条件
- [ ] v1 子 issue がすべて CLOSED
- [ ] …

## 参照
- コード: `frontend/src/app/plans/plan-detail.component.ts`
- 画面: `/plans/:id`
- 関連: #898
```

起票後 `gh issue edit` で子番号を `#N` に差し替える。

---

## 子 issue（v1）

**1 issue = 1 観測可能スコープ。** 実装方法は書かない。

**参照の制約** — `tmp/product-gap/` path は**禁止**。許可: リポジトリ内コード path + GitHub `#N` のみ。

```markdown
## 目的
<1段落>

## 背景
<なぜ v1 か>

## 完了条件
- [ ] <観測可能>
- [ ] 関連テスト GREEN（test-common）

## 依存
- なし / #N

## 親 epic
- #EPIC

## スコープ外
- …

## 参照
- 画面: `/plans/:id`
- コード: `frontend/src/app/plans/plan-detail.component.ts`
- 親 epic: #EPIC
```

**着手順:** 依存の少ない順。集約ロジック共有が要るものは依存 issue で明示。

---

## 起票コマンド例

```bash
mkdir -p tmp/product-gap
gh issue create --repo rick-chick/agrr \
  --title "..." --label enhancement --body-file tmp/product-gap/epic-body.md
```

ラベルは `gh label list --repo rick-chick/agrr` で存在確認してから付与する。

`agent-ready` は [`github-issue-creator`](../github-issue-creator/SKILL.md) §6 に従う。
