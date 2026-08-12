# サブエージェント委譲プロンプト

親エージェントは Task ツールで起動する。**毎回 `model: "composer-2.5"`** を指定する。`run_in_background: false` を既定とする。

サブエージェントは**指定の成果物パスに直接書く**（親への貼り付けのみにしない）。親はファイルの存在と内容を確認してから次フェーズへ進む。

---

## §1 現状把握（explore）

**出力先:** `tmp/product-gap/current-state.md`

```
AGRR リポジトリの現状機能を調査し、tmp/product-gap/current-state.md に直接書け。

調査対象:
- frontend ルート・主要画面
- crates/agrr-domain の bounded context
- 計画→実行→学習のループのうち薄い箇所

出力（Markdown）:
1. できること一覧（画面・API レベル）
2. ユーザーフロー（ログイン後・作業・計画）
3. 再利用可能な資産（use case, domain 型, API）
4. ファイルパス付き

プロダクト芯: 気象×GDD×最適化の計画アプリ（フル ERP ではない）。
コードは書かない。
```

---

## §2 ギャップ列挙（generalPurpose）

**出力先:** `tmp/product-gap/gap-backlog.md`

```
入力: tmp/product-gap/current-state.md を読め。

他の農業アプリにあって AGRR に弱い・ない機能をカテゴリ別に列挙し、tmp/product-gap/gap-backlog.md に直接書け。

各候補に必ず付ける:
- 自社差別化との接続（GDD/気象/最適化と連動するか）
- 計画→実行→学習のどこを閉じるか
- 既存強化で足りるか / 新規画面が要るか（初判）
- 優先度仮説 P1/P2
- 競合根拠の出典区分: 公開情報 / 既存調査 / 一般知識（未検証は「仮説」と明記）

禁止:
- 他アプリの機能をそのまま真似するだけの提案
- 実装コード・コンポーネント設計

出力: gap-backlog.md 形式の Markdown
```

---

## §3 テーマ深掘り（explore）

**出力先:** `tmp/product-gap/theme-deep-dive.md`

```
入力:
- tmp/product-gap/current-state.md
- tmp/product-gap/theme-selection.md（選定テーマ1件）

選定テーマについて深掘りし、tmp/product-gap/theme-deep-dive.md に直接書け。

出力:
1. 既存で再利用できる画面・API・分類ロジック（パス付き）
2. 足りないもの
3. UI 置き場案（画面パスレベル。コンポーネント名・実装コード禁止）
4. 既存強化案と新規画面案の比較
5. 新規画面案がある場合: new_surface_justification（既存で代替できない観測ベースの理由）
6. 競合機能の根拠（出典区分: 公開情報 / 既存調査 / 一般知識。未検証は仮説）

実装コード・コンポーネント設計は書かない。観測可能な振る舞い・画面役割まで。
```

---

## §4 重複・UXゲート G2（generalPurpose）

**出力先:** `tmp/product-gap/overlap-ux-gate.json`

```
入力:
- tmp/product-gap/current-state.md
- tmp/product-gap/theme-deep-dive.md

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G2

判定し、tmp/product-gap/overlap-ux-gate.json に JSON のみを直接書け。

verdict=fail のとき mandatory_corrections に、gates.md の該当行に沿った具体修正を書く（修正対象は theme-deep-dive.md）。

新画面案は自動 fail にしない。F4 で記載された `new_surface_justification` を G2-4 で検証する。G2-1〜3（重複・過剰・コード）を優先して判定する。
```

---

## §5 計画レビュー G3（generalPurpose）

**出力先:** `tmp/product-gap/plan-review.json`

```
入力:
- tmp/product-gap/enhancement-plan.md
- tmp/product-gap/overlap-ux-gate.json（pass 前提）
- tmp/product-gap/current-state.md

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G3

レビューし、tmp/product-gap/plan-review.json に JSON のみを直接書け。

観点:
- 画面役割・v1/v2 境界・観測可能な完了条件
- 入口と実行の両方がある場合のリスト重複
- 集約 API・新ルートの観測が enhancement-plan にあるか（要否の断定はしない）
- 実装コード・コンポーネント設計・修正方法が含まれていないか（G3-6）

verdict=fail のとき mandatory_corrections の修正対象は enhancement-plan.md。

v1 の issue 数そのものは fail 条件にしない。
```
