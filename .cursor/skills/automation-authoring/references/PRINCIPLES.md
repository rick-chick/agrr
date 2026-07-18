# Automation Authoring — 設計原則

## 目的: 人間介在なしで完遂する

Automation の目的は、**人間がラベルを付けたり UI で再開したりしなくても**、issue → 実装 → PR → CI → マージ（または意図した終了）まで **機械が完了・再開・完遂**できること。

| 求めること | 行わないこと |
|------------|----------------------|
| 滞留したら **reconcile / retry / watchdog** が拾って再開する | オプトイン漏れ・Draft 限定・ラベル欠落で **記録・再開せず止まる** |
| 既定は **対象にする**（オプトアウトで止める） | 「人間が `agent-merge` を付けたら動く」を本筋にする |
| 失敗・BEHIND・CI 赤・キャンセルを **回復経路に載せる** | 「今回はスキップ」「人間確認待ち」でパイプラインを切る |
| 責任空白（どの Worker も動かない状態）を **設計時に潰す** | 狭い例外だけ足して別の穴を残す |

**人間判断待ちは行わない。** Issue Worker は実装か close のみ。安全性は `ARCHITECTURE.md`・契約テスト・CI・Agent の修正ループで担保する。PR Merge Worker も同様に人間レビューをゲートにしない（[§目的](#目的-人間介在なしで完遂する)）。

### このリポジトリ固有の前提（一般論を設計根拠にしない）

- **「人間レビューがないから不十分」は設計根拠にしない。** 人間レビュー待ち・オプトイン・承認必須は、業界の一般的 Automation 慣習であって、本リポジトリの目的ではない。
- 目的は **人間がいなくても完遂すること**。安全性は ruleset CI・ARCHITECTURE ゲート・Agent の修正ループ・watchdog で担保する。人間レビューをゲートに追加して対処済みとみなさない。
- 一般的な「human-in-the-loop / オプトイン自動マージ」の型をそのままコピーしない。既存同型経路と [§目的](#目的-人間介在なしで完遂する) / [§全部拾う](#全部拾う--場合分けで止まる) に合わせる。

着手前チェック（[SKILL.md §0](../SKILL.md)）の「滞留時の回復経路」は、この目的を満たす一文であること。

## 全部拾う > 場合分けで止まる

「Draft のときだけ」「ラベル付きのときだけ」「BEHIND だが CI 緑のときだけ」のように **事細かな場合分け**を増やすと、必ずどこかの組み合わせで止まって人間待ちになる。

| 優先 | 意味 |
|------|------|
| **1. 全部拾う** | open 対象を広く列挙し、滞留理由（CI 赤 / BEHIND / キャンセル / stale）は **同じ reconcile が振り分ける** |
| **2. 少ないオプトアウト** | 明示的に止めるものだけ除外（blocking ラベル・fork・`[WIP]` 等） |
| **3. 場合分けは振り分け用** | `conflict` / `ci_fix` / `stuck_retry` は **起動しない理由にしない**。拾ったあと何をするかの分岐だけ |

**禁止**: 「この場合はスキップ・あの場合は人間確認」を追加して対処済みとみなすこと。未対応の穴は減らず、停止条件だけが増える。

狭い例外 PR（#354 型）を足すより、**対象を広げて全部拾える**設計を選ぶ。

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
| 依存未充足で待つ | `agent-ready` 維持 + dispatch 依存ゲート（reconcile が再判定） |
| 対応不要（確定） | §2a クローズ（`agent-closed` + `wontfix` 等） |
| 仕様曖昧・スコープ外 | エージェントが自律判断して **実装** または **close**（オープン放置禁止） |
| 着手中 | `agent-in-progress` |

`RETRY_BLOCK_LABELS` は **`agent-in-progress` のみ**（Issue Worker）。停止ラベルでキューから外さない。

## ゲート

- 判定は `scripts/*-dispatch-lib.mjs` に集約する
- primary dispatch と retry dispatch で **同じ関数** を使う
- Worker SKILL 内の triage は **判断**（実装するか close / block か）。機械ゲートの二重実装にしない
- **既定は対象・除外はオプトアウト**（blocking ラベル / fork / `CHANGES_REQUESTED` / `[WIP]` 等）。ブランチ名や追加ラベルを起動の前提にしない
- ゲート条件を足すときは「これで止まらないケースが増えないか」を先に問う（[§全部拾う](#全部拾う--場合分けで止まる)）

## retry / reconcile の標準形

| 要素 | 内容 |
|------|------|
| トリガー | `workflow_run: cancelled` **または `failure`**、15 分 cron、`workflow_dispatch` |
| 選定 | pure function、番号昇順、**1 回 1 件** |
| 送信 | `postWebhookJson`（500/502/503/429 は同一 run 内で backoff retry）+ `retry_reason` |
| concurrency | 固定 group、`cancel-in-progress: false` |
| 対象一覧 | パイプラインが扱う open 対象を **漏れなく**列挙（狭い label フィルタだけで本筋候補を落とさない） |

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
