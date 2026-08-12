# サブエージェント委譲プロンプト

親エージェントは Task ツールで起動する。`run_in_background: false` を既定とする。

---

## §1 現状把握（explore）

```
AGRR リポジトリの現状機能を調査せよ。

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

```
入力: tmp/product-gap/current-state.md の内容（親が貼る）

他の農業アプリにあって AGRR に弱い・ない機能をカテゴリ別に列挙せよ。

各候補に必ず付ける:
- 自社差別化との接続（GDD/気象/最適化と連動するか）
- 計画→実行→学習のどこを閉じるか
- 新画面が要るか / 既存強化で足りるか（初判）
- 優先度仮説 P1/P2

禁止:
- 他アプリの機能をそのまま真似するだけの提案
- 実装コード

出力: gap-backlog.md 形式の Markdown
```

---

## §3 テーマ深掘り（explore）

```
入力:
- current-state.md
- theme-selection.md（選定テーマ1件）

選定テーマについて深掘りせよ。

出力:
1. 既存で再利用できる画面・API・分類ロジック（パス付き）
2. 足りないもの
3. UI 置き場案（画面パスレベル。コンポーネント名・コード禁止）
4. 「新規ダッシュボード」案と「既存強化」案の両方を短く比較

コードは書かない。
```

---

## §4 重複・UXゲート G2（generalPurpose）

```
入力:
- current-state.md
- theme-deep-dive.md

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G2

判定せよ。出力は overlap-ux-gate.json のみ（JSON）。

verdict=fail のとき mandatory_corrections に、
「新画面破棄→既存強化」「UI情報削減」を具体的に書く。

人間が言う「既存と被る」「UXが悪化する」「コード書くな」を
ここで機械判定する。
```

---

## §5 計画レビュー G3（generalPurpose）

```
入力:
- enhancement-plan.md
- overlap-ux-gate.json（pass 前提）
- current-state.md

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G3

厳しめにレビューせよ。出力は plan-review.json のみ（JSON）。

観点:
- /work は複数農場向け、農場1件は /plans/:id/work が主戦場か
- v1 が肥大化していないか
- issue 化できる完了条件に落ちるか
```
