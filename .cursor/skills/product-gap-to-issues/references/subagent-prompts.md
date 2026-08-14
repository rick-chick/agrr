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
- GitHub backlog（選定テーマまたはギャップ候補に関連する issue）:
  - `gh issue list --repo rick-chick/agrr --search "<テーマキーワード>" --state all --json number,title,state`
  - 候補ごとに `gh issue view <N> --json number,title,state` で OPEN / CLOSED を確認
- 同一テーマのマージ済み PR:
  - `gh pr list --repo rick-chick/agrr --search "is:merged <テーマキーワード> in:title" --state merged --json number,title,mergedAt`
  - 各 PR の diff から触れたコード path を列挙（`gh pr view <N> --json files` または diff 要約）

出力（Markdown）— `tmp/product-gap/current-state.md` の必須セクション（[`artifacts.md`](artifacts.md) 参照）:
1. **既存 backlog** — 関連 issue 番号・state・タイトル要約
2. **実装済み** — マージ済み PR 番号と触れたコード path
3. **できること一覧**（画面・API レベル、コード path 付き）
4. **計画→実行→学習**の薄い箇所（上記 GitHub 観測と矛盾しない記述）
5. ユーザーフロー（ログイン後・作業・計画）
6. 再利用可能な資産（use case, domain 型, API）

必須セクション 1–4 が空のときは調査不足。親エージェントはフェーズ 2 に進まない。

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
- 既存強化で足りるか / 新規画面が要るか（初判）
- 優先度仮説 P1/P2
- 幅/深さ: 幅 | 深さ | どちらでも — 1 行理由（.cursor/skills/product-gap-to-issues/references/breadth-depth-scale.md）

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
3. UI 置き場案（画面パスレベル。コンポーネント名・実装コード禁止）
4. 既存強化案と新規画面案の比較
5. 新規画面案がある場合: new_surface_justification（既存で代替できない観測ベースの理由）
6. 深掘り打ち止め: 過剰なら幅に回す候補と理由（breadth-depth-scale.md 参照。不要なら「なし」）

コードは書かない。
```

---

## §4 重複・UXゲート G2（generalPurpose）

```
入力:
- current-state.md
- theme-selection.md（G2/G3 共通: breadth-depth-scale.md §幅 vs 深さ 形式）
- theme-deep-dive.md

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G2

判定せよ。出力は overlap-ux-gate.json のみ（JSON）。

verdict=fail のとき mandatory_corrections に、gates.md の該当行に沿った具体修正を書く。

新画面案は自動 fail にしない。G2-4（justification 未記載）と G2-1〜3（重複・過剰・コード）、G2-5〜8（深掘り打ち止め・見送り）を優先して判定する。
```

---

## §5 計画レビュー G3（generalPurpose）

```
入力:
- enhancement-plan.md
- overlap-ux-gate.json（pass 前提）
- current-state.md
- theme-selection.md（G2/G3 共通: 幅 vs 深さ 判定・見送り）
- theme-deep-dive.md（G2 入力。打ち止め・justification の整合確認）

ルーブリック: .cursor/skills/product-gap-to-issues/references/gates.md §G3

レビューせよ。出力は plan-review.json のみ（JSON）。

観点:
- 画面役割・v1/v2 境界・観測可能な完了条件
- 入口と実行の両方がある場合のリスト重複
- 集約 API・新ルートの観測が enhancement-plan にあるか（要否の断定はしない）

v1 の issue 数そのものは fail 条件にしない。
```
