# Issue パックテンプレート

起票前に `tmp/product-gap/issue-pack.md` にまとめる。本文は [`github-issue-creator/references/issue-body-template.md`](../../github-issue-creator/references/issue-body-template.md) に合わせる。

---

## 強化方針（enhancement-plan.md）

```markdown
# 強化方針: <テーマ名>

## 方針一言
<新画面なし / 既存○○を強化>

## 画面役割

| 画面 | 役割 | v1で足す | 足さない |
|------|------|----------|----------|
| | | | |

## ユーザーセグメント

| セグメント | 主に効く画面 |
|------------|--------------|
| 農場1件 | |
| 農場複数 | |

## v1 / v2

### v1（起票する）
1. …

### v2（起票しない・Epic に列挙のみ）
- …

## やらないこと
- …

## 新機能案 → 強化先 対応表

| 当初案 | 行き先 |
|--------|--------|
| | |
```

---

## Epic

**タイトル:** `[P1][UX][epic] <テーマ>（ダッシュボード新設なし）`

**ラベル:** `enhancement`（`epic` ラベルが無ければタイトルの `[epic]` のみ）

```markdown
## 目的
<2–4行>

## スコープ外
- 新規ルート …
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
- tmp/product-gap/screen-mocks.md
- コード path（調査済み）
```

起票後 `gh issue edit` で子番号を `#N` に差し替える。

---

## 子 issue（v1）

**1 issue = 1 観測可能スコープ。** 実装方法は書かない。

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
- 画面: `/path`
- コード: `path/to/file`
```

**タイトル例:**
- `[P1][UX] plans/:id/work: 期限超過タスクに遅延日数を表示`
- `[P1][UX] work: 農場カードに遅延・今日の件数サマリを表示`
- `[P1][UX] ナビ「作業記録」に遅延合計バッジを表示`

**着手順:** 依存の少ない順 → 集約ロジック共有が要るものは後。

---

## 起票コマンド例

```bash
mkdir -p tmp/product-gap
gh issue create --repo rick-chick/agrr \
  --title "..." --label enhancement --body-file tmp/product-gap/epic-body.md
```

ラベルは `gh label list --repo rick-chick/agrr` で存在確認してから付与する。
