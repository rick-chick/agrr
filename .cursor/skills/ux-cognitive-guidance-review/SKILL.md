---
name: ux-cognitive-guidance-review
description: >-
  AGRR の「わからない」状態と救済導線（L0–L4）を、ジョブシナリオ・状態マトリクス・PNG/コードでレビューし
  cognitive-guidance-review.md に書き出す。認知導線レビュー、わからないときの導線、empty state / エラー回復の UX 監査で適用する。
---

# 認知・導線レビュー（わからないときの救済）

`frontend-agent-visual-review`（見た目・i18n）と `docs/product/USER-FLOW-REVIEW.md`（ルート間遷移）を補う。**ユーザーが迷った・止まった・失敗したときに、次の有効行動へ届くか**を評価する。

## 前提（正とするファイル）

| 用途 | パス |
|------|------|
| ルート一覧 | `frontend/e2e/agent-review/route-to-png.md` |
| PNG | `frontend/e2e/agent-review/out/*.{ja,en,in}.png` |
| レイアウト/i18n レビュー | `frontend/e2e/agent-review/visual-review-results.md` |
| フロー横断 | `docs/product/USER-FLOW-REVIEW.md` |
| ジョブシナリオ定義 | [references/job-scenarios.md](references/job-scenarios.md) |
| 迷いの分類 | [references/confusion-taxonomy.md](references/confusion-taxonomy.md) |

キャプチャ手順は `frontend-css-route-audit` / `e2e:capture-for-agent`。**ユーザーに URL を求めない。**

## レビュー範囲

- **含める**: 目的の明示、空状態、エラー回復、ブロック理由、primary CTA、復帰導線、用語補助、デッドエンド
- **含めない**: CSS トークン（`audit:css-tokens`）、純レイアウトの微差（`frontend-agent-visual-review`）

## 迷いの種類（ラベル必須）

| コード | 意味 |
|--------|------|
| A | 何をすべきかわからない |
| B | 用語・概念がわからない |
| C | 状態・結果がわからない |
| D | なぜできないかわからない |
| E | どこにいるかわからない |
| F | 期待と違う |
| G | 信頼できない（影響不明） |

詳細は [references/confusion-taxonomy.md](references/confusion-taxonomy.md)。

## 導線の層（L0–L4）

| 層 | 例 |
|----|-----|
| L0 | 画面内説明・ラベル・インライン例 |
| L1 | 空状態 CTA・バナー・次ステップボタン |
| L2 | ナビ・パンくず・別画面リンク・`back_to_hub` |
| L3 | research レポート・用語集 |
| L4 | お問い合わせ |

**適切** = 迷いの種類に対し、視界内または 1 操作以内で有効行動へ届き、可能なら元タスクに復帰できる。

## 状態マトリクス（画面ごとに明示）

各 pattern について、キャプチャが表す状態を 1 行で書く。

```
データ: 0件 / あり / 読込中 / API失敗
認証: 未ログイン / ログイン済
非同期: 待機中 / 完了 / failed
```

エッジ状態（0 件・失敗・途中）を優先レビューする。happy path のみの判定は **注意** 以上にしない。

## ジョブシナリオ（必須）

[references/job-scenarios.md](references/job-scenarios.md) の J1–J8 を軸にレビューする。各ジョブについて:

1. 関連 pattern（`route-to-png.md` の #）を列挙
2. 成功条件を満たす導線があるか
3. ブロック時に L0–L4 のどれが効いているか

全ルート走査は **ジョブ完了後** に行う（オプション）。パイロットはジョブ関連 pattern のみでも可。

## チェックリスト（10 問 — 各画面・各状態）

| # | 質問 | No のとき |
|---|------|-----------|
| Q1 | この画面の目的が 1 文で言えるか（L0） | 迷い A |
| Q2 | primary CTA が 1 つ、視界内にあるか | 迷い A |
| Q3 | 操作不可時に理由＋対処がセットか（L0/L1） | 迷い D |
| Q4 | 0 件時に「なぜ空か・何を作るか・どこへ」のいずれか欠けていないか | 迷い A/D |
| Q5 | 失敗時に再試行 or 代替導線 or 戻りがあるか | 迷い C/F |
| Q6 | 見出し・パンくず・ナビ active が一致しているか | 迷い E |
| Q7 | 初見に必要な専門用語に補助があるか | 迷い B |
| Q8 | 導線先がブロックの直接原因を解消するか | 導線不適切 |
| Q9 | 導線後に元タスクへ復帰できるか | 復帰不可 |
| Q10 | デッドエンド（クリック先なし・戻りなし）にならないか | P0 候補 |

## バッチ運用

- 1 ターンで **1–2 ジョブ** または **10–15 pattern** ずつ
- 各バッチで対象ジョブ ID・pattern 行番号・参照 PNG を明示
- 全バッチ後 **1 ファイル**にマージ

## 必須アウトプット

**`frontend/e2e/agent-review/cognitive-guidance-review.md`**（パス固定。ユーザーが別名を指示したときだけ従う）。

### 1. メタ

- レビュー日（UTC 可）
- 対象ジョブ（例: J1–J5）と pattern 行範囲
- キャプチャ種別（`e2e:capture-for-agent` 等）と前提一言
- 参照: `visual-review-results.md` の有無・日付

### 2. ジョブサマリ表

```
| ジョブ | 関連 # | 結果 | 迷い種類 | 導線層 | 指摘 |
```

結果: `OK` / `注意` / `要確認`

### 3. 画面サマリ表（pattern 単位）

```
| # | pattern | 状態 | 迷い | 導線 | Q失敗 | 結果 | 指摘 |
```

- **迷い**: A–G（複数は `A,D`）
- **導線**: 最も効いている層 `L0`–`L4`、または `なし`
- **Q失敗**: チェックリストで No になった番号（例: `Q3,Q5`）

### 4. 指摘の詳細（`注意` / `要確認` のみ）

`collect-ux-findings` 互換形式:

```
1. **#N pattern — 状態** — 迷い: D / 導線: L1不足 / 提案: …
```

区切りは **全角 em dash `—`**。

### 5. 優先度

| 優先度 | 条件 |
|--------|------|
| P0 | コアジョブのデッドエンド、サイレント失敗、データ損失 |
| P1 | 導線はあるが見つけにくい、技術エラーのみ、復帰不可 |
| P2 | 用語補助不足、CTA 優先度のずれ |

### 6. 禁止

- 表なしで「だいたい OK」だけで締める
- 迷い種類・導線層のラベル省略
- キャプチャ未実施の状態を「OK」とする

## 実行手順（エージェント）

1. `route-to-png.md` と `references/job-scenarios.md` を読む
2. PNG が無ければ `frontend-css-route-audit` でキャプチャ（verify 通過）
3. ジョブごとに PNG（ja 必須、en/in は導線文言が違う画面）と該当 component / presenter を読む
4. 状態マトリクス・10 問・迷い種類・導線層を記録
5. `cognitive-guidance-review.md` を書く
6. Issue 化は **`ux-issue-pipeline`** フェーズ 4 以降（起票はユーザー明示まで）

## エージェント禁止

- レイアウト/i18n のみの指摘をこの成果物に重複列挙（`visual-review-results.md` へ）
- ユーザーに「どの画面を見るか」を聞いて逃げる
- コード未読で「ヘルプがあるはず」と推測

## 関連

- キャプチャ: **`frontend-css-route-audit`**
- レイアウト/i18n: **`frontend-agent-visual-review`**
- Issue パイプライン: **`ux-issue-pipeline`**（フェーズ 2b = 本スキル）
