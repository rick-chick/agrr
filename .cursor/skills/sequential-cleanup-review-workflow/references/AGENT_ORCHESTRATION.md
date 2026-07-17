# エージェントオーケストレーション（順次クリーンアップ）

**二重ループ**: `while tasks`（shell）の各周で `agent A1 → A2 → … → D1 → D2`（Task 1 Step ずつ）。  
起動時は [DUAL_LOOP.md](DUAL_LOOP.md) の **`cleanup-workflow-tick.sh`** から始める。**tick 未実行で A1 に進まない。**

手作業で一つずつやっていたときの精度を、**オーケストレーター + ステップ専用サブエージェント**で再現する。親エージェントは A〜D を自分で実装せず、**1 ステップ = 最低 1 サブエージェント起動**で進める。

## なぜ弱くなりやすいか

| 手作業 | エージェントが起きやすい手順逸脱 |
|--------|------------------------------|
| ファイルを 1 件ずつ開いて確認 | A〜D を 1 ターンで「完了」と報告 |
| 削除前に到達性を個別調査 | `rg` ゼロヒットだけでセーフ削除 |
| テスト層を spec ごとに判定 | 変更した spec をまとめてスキップ |
| ARCHITECTURE を層ごとに読む | 「問題なし」の一文だけ |
| ステップ間で一度立ち止まる | D を先送りして次の改修へ |

## 役割分担

| 役割 | 誰 | やること | やらないこと |
|------|-----|----------|--------------|
| **オーケストレーター** | 親エージェント | マニフェスト作成、ステップ委譲、ゲート検証、次ステップ起動 | A〜D のソース編集・削除・テスト実行の直接実施 |
| **調査** | `explore`（`readonly: true`） | 候補列挙・層判定・根拠収集 | ファイル変更 |
| **実施** | `generalPurpose` または層別エージェント | 調査結果に基づく削除・移動・TDD | スコープ外の改修 |
| **レビュー** | `explore`（`readonly: true`） | ARCHITECTURE 照合・条項列挙 | 実装修正（要修正は C に戻す） |

[`use-skills-on-edit.mdc`](../../../rules/use-skills-on-edit.mdc) の「並列委譲」は **本ループの A〜D には適用しない**。A→B→C→D は厳密に直列。層別の複数移動は **同一ステップ内**（例: B で spec が 2 層）のみ並列可。

## Task 起動 — モデル（必須）

**Task ツールで `explore` / `generalPurpose` / 層別サブエージェントを起動するときは、毎回 `model: "composer-2.5"` を指定する。**

| 指定 | 結果 |
|------|------|
| `model` **省略** | Cursor 既定で **Composer 2.5 Fast** になりやすい（精度低下） |
| `model: "composer-2.5"` | 親チャットと同じ **Composer 2.5** |
| `model: "composer-2.5-fast"` | **禁止**（本 workflow では使わない） |

```text
Task(subagent_type="explore", model="composer-2.5", readonly=true, ...)
Task(subagent_type="generalPurpose", model="composer-2.5", ...)
Task(subagent_type="usecase-frontend", model="composer-2.5", ...)
```

`.cursor/agents/*.md` の `model: inherit` はカスタムサブエージェント用。組み込み `explore` / `generalPurpose` には **inherit 効かない** — 上記の明示が必要。

## 開始前 — マニフェスト（Step 0）

```bash
.cursor/skills/sequential-cleanup-review-workflow/scripts/collect-modification-scope.sh \
  --unit-name "<修正単位名>" \
  --out tmp/cleanup-unit-<slug>.md
```

オーケストレーターは `tmp/cleanup-unit-<slug>.md` を開き、スコープ一覧を目視確認してから Step A へ。**マニフェストが無い状態で A に入らない。**

テンプレの残り欄: [CHECKLIST.md](CHECKLIST.md) の「修正単位マニフェスト」。

## ステップごとの委譲（必須パターン）

各ステップは **調査（readonly）→ ゲート確認 → 実施** の 2〜3 起動。調査と実施を **同一サブエージェントにまとめない**。

### Step A — デッドコード

**A1 調査** — Task: `explore`, **`model: composer-2.5`**, `readonly: true`

プロンプトに含めるもの:
- マニフェストのスコープファイル一覧
- [`dead-code-removal-workflow` Phase A](../../dead-code-removal-workflow/SKILL.md) の探索範囲（Rust: `crates/`, Angular: `frontend/src/`）
- 返却形式（下記）

返却必須:

```markdown
## A1 調査結果
| 候補 | 種別(file/method/import) | 根拠種別(到達不能/重複/obsolete) | 根拠（1行） | 判定(削除可/要確認/維持) |
```

**ゲート**: 「削除可」行が 0 件なら A2 はスキップ可。`要確認` が残る間は A2 に進まない（調査継続）。

**A2 実施** — Task: `generalPurpose`, **`model: composer-2.5`**

- A1 の「削除可」のみ削除
- メソッド単位は [`find-method-dead-code`](../../find-method-dead-code/SKILL.md) 手順に従う
- 削除後: 触れたテストを `test-common` で個別 GREEN
- マニフェストの `## Step A` に削除一覧とテスト結果を追記

### Step B — 責務外テスト

**B1 調査** — Task: `explore`, **`model: composer-2.5`**, `readonly: true`

スコープ内の `*spec.ts` / `*_test.rs` / `test/` を **1 ファイルずつ** [CHECKLIST の判定木](CHECKLIST.md) で分類。

返却必須:

```markdown
## B1 調査結果
| spec ファイル | 正しい層か | 扱い(維持/移動/統合/セーフ削除) | 移動先 or 根拠 |
```

**ゲート**: 全行に「扱い」が付いていること。`移動` には移動先パス必須。

**B2 実施** — `移動` 行ごとに **層別エージェント**（[`CODE_MODIFICATION_SKILLS.md`](../../../references/CODE_MODIFICATION_SKILLS.md) のテスト列）、**`model: composer-2.5`**

各移動は [`tdd-on-edit`](../../tdd-on-edit/SKILL.md): 移動先 RED → GREEN → 元 spec セーフ削除。

**B3 検証** (`shell` または親が実行)

- 変更した spec パスを `test-common` で個別 GREEN
- マニフェスト `## Step B` に追記

### Step C — 責務外コード

**C1 調査** — Task: `explore`, **`model: composer-2.5`**, `readonly: true`

スコープ内の実装ファイルを層定義（`ARCHITECTURE.md`）と照合。

返却必須:

```markdown
## C1 調査結果
| ファイル | 層 | 責務外の塊 | 移動先層 | 扱い(維持/移動) |
```

**C2 実施** — `移動` 行ごとに層別エージェント（CODE_MODIFICATION_SKILLS の実装列）、**`model: composer-2.5`**。移動は TDD。移動で生じたデッドは **Step A に戻さず** C2 内でセーフ削除してよい（同一修正単位内）。

**C3 検証**: 触れた実装・spec を `test-common` で個別 GREEN。マニフェスト `## Step C` に追記。

### Step D — レビュー

**D1 照合** — Task: `explore`, **`model: composer-2.5`**, `readonly: true`

- 触れた層の `ARCHITECTURE.md` `## What we require` と `## Prohibited practices` を **条項番号付き**で列挙
- 問題があれば条項番号とファイルを返す（修正はしない）

返却必須: [CHECKLIST のレビュー記録テンプレ](CHECKLIST.md) を埋めた markdown。

**機械取込用 TSV（必須）** — `tmp/cleanup-d-review-<parent-slug>.tsv` に **すべての行** を書く（スコープ内外・要確認を問わず。AI が取捨選択しない）:

```
id	kind	summary	evidence	source
```

D1 後、親は **判断せず shell のみ**（**同一ターンで外側 until gate**。ユーザーに prepare を促す **禁止** — [ORCHESTRATOR_OUTER_LOOP.md](ORCHESTRATOR_OUTER_LOOP.md)）:

```bash
cleanup-outer-loop-orchestrate.sh --parent-slug <parent-slug> post-d
while ! cleanup-outer-loop-orchestrate.sh --parent-slug <parent-slug> gate; do
  cleanup-outer-loop-orchestrate.sh --parent-slug <parent-slug> next
  # ORCHESTRATOR_PROMPT_PATH → L2 Step委譲 → cleanup-agent-handoff.sh
done
```

**D1 ゲート**: C2 ↔ D1 で直せるものは内側で先に直してよい。**D1 がレビューで挙げた候補は例外なく TSV 行**（「同一サイクル要修正＝いいえ」「任意改善」「必須残課題に該当しない」で除外 **禁止**）。

**D2 テスト** (親または `shell`)

1. 関連 spec 個別 GREEN（`test-common`）
2. 層に応じた全体（domain / frontend / `run-rust-contract-tests.sh`）
3. [`test-slow-detection`](../../test-slow-detection/SKILL.md)

マニフェスト `## Step D` を完了にし、チェックリストの D にチェック。**D1 候補は TSV 記載済み + ingest 済み**（`d-review-validate.sh` / `gate` で確認）。

## 外側ループ — 残課題スタック（L1 shell + L2 親）

内側 D 完了後、backlog に `pending` があれば L1 `run-outer-loop.sh gate/prepare` で外側を回す。**pending 0 まで** 次へ進まない。**ユーザーに「続けますか？」と聞かない。**

```
L1: gate / pop / mark-done（shell）
while backlog.pending > 0:
  L1: pop → PROMPT_PATH
  L2: 親が TDD 委譲 + 内側 Step 0→A1→A2→…→D2（各 Step サブエージェント委譲）
  L1: mark-done → 新残課題 push
```

**L2 親は内側 A〜D を直実施しない**（[内側ループ](#オーケストレーターの-1-ターン内ループ内側) と同じ）。  
**L1 導入後も A1/B1/C1/D1 の explore 委譲は省略不可** — [SCRIPT_DRIVEN_LOOP.md](SCRIPT_DRIVEN_LOOP.md) 3 層参照。

## オーケストレーターの 1 ターン内ループ（内側）

```
Step 0: collect-modification-scope.sh → マニフェスト作成
Step A1 → ゲート → (A2) → マニフェスト更新
Step B1 → ゲート → B2… → B3 → マニフェスト更新
Step C1 → ゲート → C2… → C3 → マニフェスト更新
Step D1 → ゲート → (C へ戻る or) D2 → マニフェスト完了
次の修正単位へ（または PR / コミット）
```

**同一ターンで次の修正単位に進むのは、直前単位のマニフェストで D が完了しているときのみ**（[`agent-conventions`](../../../rules/agent-conventions.mdc) のユーザー発話待ち禁止と整合）。

## サブエージェント共通プロンプト断片

各委譲プロンプトの末尾に必ず付ける。Task 起動時は **`model: "composer-2.5"`**（[Task 起動 — モデル](#task-起動--モデル必須)）。

```
- あなたは sequential-cleanup-review-workflow の Step <X><n> 専用。スコープ外の改修・依頼外の修正は禁止（project-necessary-code-only）。
- 調査フェーズでは readonly。削除・移動は調査結果の表に載ったものだけ。
- 返却は上記の必須 markdown 表形式。表なしの「問題なし」だけは不可。
- テストは test-common 経由のみ。npm test / cargo test 直叩き禁止。
- さらにサブエージェントへ委譲しない（連鎖禁止）。終了時にゲート用の表を必ず返す。
```

## 複数修正単位があるとき

1  PR に複数束がある場合、**単位ごとにマニフェストを分ける**（`tmp/cleanup-unit-<slug-1>.md` …）。
オーケストレーターは slug-1 の D 完了後にのみ slug-2 の Step 0 へ。

## github-issue-worker との関係

1 issue = 1 修正単位 = 1 マニフェスト。Issue Worker の §4 は本オーケストレーションを **省略せず** 適用する（TDD GREEN 直後・PR 前）。
