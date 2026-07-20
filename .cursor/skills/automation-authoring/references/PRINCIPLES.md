# Automation Authoring — 設計原則

## 目的: 人間介在なしで完遂する

Automation の目的は、**人間がラベルを付けたり UI で再開したりしなくても**、issue → 実装 → PR → CI → マージ（または意図した終了）まで **機械が完了・再開・完遂**できること。

| 求めること | 行わないこと |
|------------|----------------------|
| 滞留したら **reconcile / retry / watchdog** が拾って再開する | オプトイン漏れ・Draft 限定・ラベル欠落で **記録・再開せず止まる** |
| 既定は **対象にする**（オプトアウトで止める） | 「人間が `agent-merge` を付けたら動く」を本筋にする |
| 失敗・BEHIND・CI 赤・キャンセルを **回復経路に載せる** | 「今回はスキップ」「人間確認待ち」でパイプラインを切る |
| 責任空白（どの Worker も動かない状態）を **設計時に潰す** | 狭い例外だけ足して別の穴を残す |

**人間判断待ちは行わない。** Issue Worker は実装か close のみ。PR Merge Worker も人間レビューをゲートにしない。安全性は `ARCHITECTURE.md`・契約テスト・CI・Agent 修正ループで担保する。

### このリポジトリ固有の前提

- **人間レビュー待ち・オプトイン・承認必須は設計根拠にしない**（業界慣習であり本リポジトリの目的ではない）
- 安全性は ruleset CI・ARCHITECTURE ゲート・watchdog で担保する
- human-in-the-loop 型をそのままコピーしない。[§目的](#目的-人間介在なしで完遂する) / [§全部拾う](#全部拾う--場合分けで止まる) に合わせる

着手前チェック（[SKILL.md §0](../SKILL.md)）の「滞留時の回復経路」は、この目的を満たす一文であること。

## 全部拾う > 場合分けで止まる

「Draft のときだけ」「ラベル付きのときだけ」「BEHIND だが CI 緑のときだけ」のように **事細かな場合分け**を増やすと、必ずどこかの組み合わせで止まって人間待ちになる。

| 優先 | 意味 |
|------|------|
| **1. 全部拾う** | open 対象を広く列挙し、滞留理由（CI 赤 / BEHIND / キャンセル / stale）は **同じ reconcile が振り分ける** |
| **2. 少ないオプトアウト** | 明示的に止めるものだけ除外（blocking ラベル・fork・`wip` ラベル等） |
| **3. 場合分けは振り分け用** | `conflict` / `ci_fix` / `stuck_retry` は **起動しない理由にしない**。拾ったあと何をするかの分岐だけ |

**禁止**: 「この場合はスキップ・あの場合は人間確認」を追加して対処済みとみなすこと。未対応の穴は減らず、停止条件だけが増える。

狭い例外 PR（#354 型）を足すより、**対象を広げて全部拾える**設計を選ぶ。

## 思想優先（最小パッチより上）

修正・レビュー・提案は **本書の原則に沿った案**を最小差分より先に示す。詳細は [`automation-philosophy-priority.mdc`](../../../rules/automation-philosophy-priority.mdc)。

触る変更では、範囲内の**既存本文パースも同一変更で除去**する（別 PR は規約上の障害時のみ）。

## 二層分離

```
GitHub イベント
  → Actions（ゲート・ラベル・reconcile）
  → webhook
  → Cursor Cloud Agent（スキル・判断・PR）
    → GitHub 副作用
```

Cloud Agent はリポジトリを clone してスキルを読む。**ローカル Docker / ng serve は使えない**。

## ラベル契約

| 用途 | 正しい経路 |
|------|------------|
| 依存未充足で待つ | `agent-ready` 維持 + Agent がコメントのみで終了（機械層は dispatch を止めない。reconcile が再送） |
| 対応不要（確定） | §2a クローズ（`agent-closed` + `wontfix` 等） |
| 仕様曖昧・スコープ外 | エージェントが自律判断して **実装** または **close**（オープン放置禁止） |
| 着手中 | `agent-in-progress` |

`RETRY_BLOCK_LABELS` は **`agent-in-progress` のみ**（Issue Worker）。停止ラベルでキューから外さない。

## 機械ゲートとエージェント判定

**本文・コメント・依存ラベル契約のパースは機械層で禁止。** regex・grep・ヒューリスティックは **Cursor Agent（Worker SKILL）のみ**。機械層は GitHub API 構造フィールド（`closingIssuesReferences`、`labels` のイベント契約、`mergeable` 等）だけを読む。

判断が要るときは webhook で Agent を起動。パース・例外ラベルで dispatch を減らさない（総コストはエージェント起動の方が小さい傾向 — 改修履歴参照）。コスト低減は構造フィールドゲート・dispatch lib 単一化・reconcile 1 件選定・SKILL 明確化・watchdog 等で行う（[automation-philosophy-priority.mdc §コスト低減](../../../rules/automation-philosophy-priority.mdc)）。

GitHub Actions / `*-dispatch-lib.mjs` は **狭い機械ゲート**のみ（イベント・マージ可否・in-progress・reconcile 選定）。二層を混ぜない。

| 層 | 担当 | 例 |
|----|------|-----|
| **機械ゲート**（Actions / dispatch lib） | 起動・再送・選定の可否だけ | マージ済みのみ、`agent-in-progress` あり → 送らない、open fix PR あり → implement 送らない |
| **エージェント判定**（Automation + SKILL） | 本文・コメント・スコープ・依存の判断 | `gh` で本文を読む triage、epic クローズ、依存未充足ならコメントのみ |

**機械ゲートの入力**は GitHub API 構造フィールドに限る。本文・コメントテキストのパース、依存ラベル契約は含めない。

**禁止（Actions / dispatch lib）**: 本文パース、**コメントパース**、エージェント triage の workflow bash 複製。

**エージェント判定**: SKILL に従い `gh` で読む。結果をコメント（人間向け）・Memory に残す。対象外は **exit 0**（理由は Memory またはコメントに短く）。

**UX Campaign 等の post-merge レビュー**も同型: Actions はマージイベントと webhook 中継まで。キャンペーン対象か・残件起票するかは **UX Campaign Loop SKILL** が `gh` で本文を含めて観測し判断する。

### 既存パースの扱い

機械層の既存パースも技術負債。発見したら **直ちに解消**（[`no-convenience-tech-debt.mdc`](../../../rules/no-convenience-tech-debt.mdc)）。

## ゲート

- **起動判定・選定**は `scripts/*-dispatch-lib.mjs` に集約する（webhook payload に `action` は載せない。Delivery Agent が GitHub を観測して分岐）
- **依存判断**は **Agent のみ**（機械層は dispatch を止めない）。本文・コメントの regex / `#N` パースは禁止（[§機械ゲートとエージェント判定](#機械ゲートとエージェント判定)）
- primary dispatch と retry dispatch で **同じ関数** を使う
- Worker SKILL 内の triage は **エージェント判定**（実装するか close / block か）。機械ゲートの二重実装にしない
- **既定は対象・除外はオプトアウト**（blocking ラベル / fork / `CHANGES_REQUESTED` / `wip` ラベル等）。ブランチ名や追加ラベルを起動の前提にしない
- ゲート条件を足すときは「これで止まらないケースが増えないか」を先に問う（[§全部拾う](#全部拾う--場合分けで止まる)）

## retry / reconcile の標準形

| 要素 | 内容 |
|------|------|
| トリガー | `workflow_run: cancelled` **または `failure`**、15 分 cron、`workflow_dispatch` |
| 選定 | pure function、番号昇順、**1 回 1 件** |
| Issue Worker reconcile 選定 | 上記に加え **`implement` 優先** → `epic_close_check`、同順位は番号昇順、直前 schedule dispatch 後回し（[`issue-worker-dispatch-lib.mjs`](../../../scripts/issue-worker-dispatch-lib.mjs) の `selectReconcileDispatchCandidate`） |
| 送信 | `postWebhookJson`（500/502/503/429 は同一 run 内で backoff retry）+ `retry_reason` |
| concurrency | 固定 group、`cancel-in-progress: false` |
| 対象一覧 | パイプラインが扱う open 対象を **漏れなく**列挙（狭い label フィルタだけで本筋候補を落とさない） |
| PR reconcile 前処理 | 陳腐化 PR close・未リンク `agent-no-merge`（[`pr-merge-worker-retry-dispatch.mjs`](../../../scripts/pr-merge-worker-retry-dispatch.mjs) `reconcilePrep`） |

primary dispatch の webhook POST も `scripts/post-cursor-webhook.mjs`（`webhook-post-lib.mjs`）経由。恒久 4xx はジョブ失敗（無限ループにしない）。

## 本筋と救済

| 層 | 目的 |
|----|------|
| **本筋** | primary dispatch が正常系で完遂まで進む |
| **救済（reconcile）** | キャンセル・失敗・BEHIND・CI 赤・stale in-progress など **滞留を自動再開**する |

- 救済は「レガシー互換のおまけ」ではない。**完遂のための必須層**（新規 dispatch にはほぼ必須）
- 本筋を狭くして救済に押し付ける設計にしない。本筋が広いほど穴が減る
- 救済だけが唯一の経路になっても、**止まらず再開できる**なら目的には沿う。ただし本筋を壊してよい意味ではない

## テスト

| 層 | 必須 |
|----|------|
| dispatch lib | `node --test scripts/*-dispatch-lib.test.mjs` |
| workflow 契約 | `verify-*-dispatch-workflow.test.mjs` |
| E2E | 実 issue/PR + Actions ログ + 副作用（[CHECKLIST.md](CHECKLIST.md)） |

unit test GREEN は E2E 完了の代替にならない。

**責任空白の回帰テスト**: 「ラベルなし ready PR + CI FAIL」「BEHIND + 必須 CI 赤」など、以前止まっていた形を unit で固定する。

## 監視

新規 dispatch workflow は `automation-pipeline-watchdog` の `DISPATCH_WORKFLOW_NAMES` に登録する。壊れたときに毎時検知できるようにする。
