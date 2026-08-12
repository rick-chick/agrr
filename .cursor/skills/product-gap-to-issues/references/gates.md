# ゲート判定（G2 / G3）

人間が行っていた **方針転換・レビュー** をサブエージェントが機械判定する。出力は JSON。

## 共通 JSON 形

```json
{
  "gate": "overlap-ux-guard | plan-review",
  "verdict": "pass | fail | blocked",
  "summary": "一行要約",
  "findings": ["観測ベースの指摘"],
  "mandatory_corrections": ["次の修正で必須"],
  "blocked_reason": "blocked のときのみ"
}
```

| verdict | 意味 |
|---------|------|
| `pass` | 次フェーズへ |
| `fail` | 親エージェントが修正対象成果物を直し、同ゲートを再実行 |
| `blocked` | ユーザー問い合わせ（依頼と事実の矛盾・確定不能） |

### fail 時の修正対象

| ゲート | 修正する成果物 |
|--------|----------------|
| G2 | `theme-deep-dive.md` |
| G3 | `enhancement-plan.md` |

### fail ループ（収束条件）

固定回数での打ち切りはしない。次のいずれかで停止する:

1. **`pass`** — 次フェーズへ
2. **同一の `mandatory_corrections` が連続 2 回** — ゲート JSON を `verdict: "blocked"` で**上書き**し `blocked_reason` を記録。ユーザー問い合わせ（[`user-request-project-alignment.mdc`](../../../rules/user-request-project-alignment.mdc)）
3. **修正不能と判断** — ゲート JSON を `verdict: "blocked"` で**上書き**し `blocked_reason` を記録

`blocked` への格上げ時、親は `overlap-ux-gate.json`（G2）または `plan-review.json`（G3）を blocked 内容で上書き保存する。

### ゲート JSON 検証（親エージェント）

スクリプトは新設しない。親がサブエージェント返却後に次を検証する:

- 必須キー: `gate`, `verdict`, `summary`, `findings`, `mandatory_corrections`
- `verdict` が `pass` のとき `mandatory_corrections` は空配列
- `verdict` が `fail` のとき `mandatory_corrections` は非空
- `verdict` が `blocked` のとき `blocked_reason` が非空
- `gate` が当該ゲート名と一致（G2: `overlap-ux-guard`, G3: `plan-review`）

不正なら同一ゲートを再委譲する（`model: "composer-2.5"`）。**不正 JSON が連続 2 回**のときは、上記と同様にゲート JSON を `verdict: "blocked"` で上書きし `blocked_reason` に検証失敗理由を記録する。

---

## G2: 重複・UXガード（overlap-ux-guard）

**タイミング**: フェーズ 5（フェーズ 4 深掘りの直後）。

### 入力

- `tmp/product-gap/current-state.md`
- `tmp/product-gap/theme-deep-dive.md`

### 判定の順序

1. **既存強化で足りるか**を先に検討する（推奨順序。自動 fail にはしない）
2. 新画面・新ルートを含む場合は、フェーズ 4 で記載された **`new_surface_justification`** を検証する（記載は F4、検証は G2）
3. 下表の **fail 条件**に該当するか判定する

### fail 条件（1つでも該当 → `fail`）

| # | 質問 | fail 時の修正（`theme-deep-dive.md`） |
|---|------|--------------------------------------|
| G2-1 | 既存画面と **同じタスク一覧・同じ操作** を二重に載せるか？ | 一覧・操作は1画面に限定し、他は導線のみ |
| G2-2 | 深掘り成果物に **実装コード・コンポーネント設計** が含まれるか？ | 削除し画面役割・振る舞いレベルに戻す |
| G2-3 | テーマに対し **情報量が過剰**か？（根拠なしのチャート・カード・横断一覧の積み上げ） | 削減案を書く。詳細は既存分析画面へ |
| G2-4 | **新画面・新ルート**があり、既存で代替不可の理由が **観測ベースで未記載**か？ | `new_surface_justification` を追記するか、既存強化に差し替え |

### pass の条件

- 画面ごとの **役割分担**が言える
- 新画面を含む場合は **justification が深掘りにある**
- UX の追加がテーマとユーザーセグメントに **比例**している

### blocked の例

- 既存機能の有無が調査で確定できない
- 依頼とプロダクト芯（計画アプリ）が両立せず、ユーザー判断が必要

### 人間指摘との対応

| 指摘 | ゲートでの扱い |
|------|----------------|
| 既存と被る | G2-1 |
| コード書くな | G2-2 |
| 詳細に引きずられて UX 悪化 | G2-3（テーマに応じた過剰判定） |
| 新機能要る？ | 自動 fail しない。G2-4 で justification の有無を確認 |

---

## G3: 計画レビュー（plan-review）

**タイミング**: フェーズ 7（`enhancement-plan.md` 完成後、モック・起票の前）。

### 入力

- `tmp/product-gap/enhancement-plan.md`
- `tmp/product-gap/overlap-ux-gate.json`（G2 `pass` 前提）
- `tmp/product-gap/current-state.md`

### fail 条件

| # | 質問 | fail 時（`enhancement-plan.md`） |
|---|------|----------------------------------|
| G3-1 | **画面ごとの役割**が表または同等の構造で明示されているか？ | 役割表を追加 |
| G3-2 | **v1 と v2 の境界**が書かれているか？ | v2 へ送る項目を分離 |
| G3-3 | **完了条件**が観測可能か（issue 化できるか）？ | 曖昧語を具体化 |
| G3-4 | **スコープ外**が列挙されているか？ | 追記 |
| G3-5 | 入口画面と実行画面の **両方**がある場合、同じリストの **重複**が残っていないか？ | サマリ vs 実行に再分割 |
| G3-6 | 成果物に **実装コード・コンポーネント設計・修正方法** が含まれるか？ | 削除し観測可能な振る舞い・画面役割までに戻す |

### 推奨（fail にしない）

- 対象ユーザーセグメント（農場1件 / 複数）への影響の記載
- v1 issue 数の抑制（境界が明確なら issue 数自体は固定しない）
- 集約 API・新ルートの要否は **観測**（農場数・API 呼び出し・既存上限）を `enhancement-plan.md` に書くこと

### pass の条件

- 計画が **起票可能な粒度**になっている
- G2 の `mandatory_corrections` が反映されている

### blocked の例

- v1 / v2 の境界が依頼と矛盾し、ユーザー判断が必要
- 完了条件を観測可能に具体化できない（前提データ・仕様が未確定）
- 集約 API の要否が既存アーキテクチャと両立するか調査で確定できない
- 同一の `mandatory_corrections` が連続 2 回再発

`blocked` 時は [`user-request-project-alignment.mdc`](../../../rules/user-request-project-alignment.mdc) に従いユーザーへ問い合わせする。

---

## 集約 API・新ルートの判断（G2/G3 共通の観測項目）

fail 条件ではない。`enhancement-plan.md` に必ず書く:

| 観測 | 記載例 |
|------|--------|
| 対象リソース上限 | 農場数・計画数（`ARCHITECTURE.md` 等） |
| 想定 API 呼び出し回数 | 農場あたり・セッションあたり |
| 新ルートの要否 | 既存ルートで足りない理由 |
| 集約 API の要否 | フロント並列で足りるか / 後続 issue か |
