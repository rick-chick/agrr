---
name: clean-architecture-violation-fix-workflow
description: >-
  Rails / Angular の Clean Architecture 違反を反復修正するワークフロー。外側ループ（洗い出し → 修正 → コミット →
  再洗い出し）と内側ループ（実装 → レビュー → ARCHITECTURE.md ゲート 1 回目／2 回目 → 振る舞いチェック）を回す。
  洗い出しは ARCHITECTURE.md の規約と照らし、コードベースを調査して気になる点を列挙する。ARCHITECTURE.md を単一ソースとし、
  本 SKILL に禁止事項を二重定義しない。違反削減・新規実装・単発変更は同一の外側・内側ループ。
---

# Clean Architecture 違反修正ワークフロー

## ループ構造

- **外側**: セクション0 → セクション1〜セクション5 → セクション6 → セクション0 を繰り返す。
- **内側**: セクション1 → セクション2 → セクション3 → セクション4（アーキテクチャゲート 1 回目 → 2 回目 → 振る舞いチェック）→ セクション5（必要なら セクション2 へ戻る）。
- **修正単位**: 1 イテレーションで扱う違反の束。同一原因・境界・ユースケース筋でまとめ、内側ループで追えるサイズに分割する。

## When to Use

- Clean Architecture 違反の是正を [`ARCHITECTURE.md`](../../../ARCHITECTURE.md) の境界に沿って進めたいとき（既存違反の削減・新規実装の差分の締め）。
- **セクション0 は省略しない**（セクション4 ゲートも省略不可）。

## 新規実装・機能追加（内側ループの前提）

違反削減でも新規でも、**セクション1〜5 は同一**。実装前に `ARCHITECTURE.md` の `## What we require` と `## Prohibited practices` を読み、触れる domain / Gateway IF / adapter 実装 / Presenter / `CompositionRoot` / 契約に対応する条項を確認する。サブエージェントへ渡すプロンプトに、契約パス・feature 名に加え「**違反を増やさない**」を含める。単発変更は [`use-skills-on-edit.mdc`](../../rules/use-skills-on-edit.mdc)。要件からの機能一式は [`feature-orchestrator.mdc`](../../rules/feature-orchestrator.mdc)（Phase 締め後、累積 diff でセクション4）。

## サブエージェント委譲

実装をサブエージェントに任せる場合も、親はセクション0（スコープ固定）・セクション4〜セクション6（ゲート・振る舞いチェック・コミット）に責任を持つ。委譲規律は [`use-skills-on-edit.mdc`](../../rules/use-skills-on-edit.mdc)。委譲プロンプトには契約パス・feature 名・触ってよい範囲・終了条件を書き、返却 diff をセクション0 で固定した修正単位から逸脱させない。

## 0. 洗い出し・優先順位

[`ARCHITECTURE.md`](../../../ARCHITECTURE.md) の規約と照らし、コードベースを調査して気になる点を洗い出し、**修正単位**に束ねる。`ARCHITECTURE.md` を単一ソースとし、本 SKILL に禁止の正解像を二重定義しない。

`git diff` / `git status` だけでは洗い出しを代替しない（直近差分に偏り、編集していないファイルに残る違反を見落とす）。

**特定文字列の grep だけで洗い出しを終えない**（漏れと誤判定が起きる）。禁止条項の**意味**と型・境界・契約に照らして読む。

検出した逸脱は修正単位として**省略せず**追跡可能な形に残す（会話での列挙・コミット説明・契約／ADR など、チームが追える手段でよい）。「今回だけ」「後で」「スコープ外」を理由に **`ARCHITECTURE.md` と矛盾する放置**をしない（[`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc)）。

- **作業スコープ**: 洗い出しで得た修正単位の一覧から、**先頭**を今回のセクション1〜6 に固定する（ユーザーが別順を明示しない限り、迷ったら先頭）。再現可能な並べ方（辞書順・経路順など）をその場で決める。
- **修正単位の束ね方**: 同一原因・境界・ユースケース筋で関連違反をまとめる。複数ファイル・複数禁止条項を含めてよいが、内側ループで追えるサイズにし、無関係な違反を混ぜない。スコープ外のついで修正はしない。
- **大きいテーマ・横断整理**: 1 イテレーションに収まるよう セクション0 で必ず分割する。「どの境界から」「どれを先に」をユーザーに委ねず、再現可能な基準（直前の洗い出し一覧の先頭、`lib/domain/<name>/` の辞書順、ファイルパス辞書順など 1 つ）を添え、分割後の一覧の**先頭**を今回の作業スコープに固定する。

## 1. 実装

- 実装前に [`clean-architecture-goal-statement/SKILL.md`](../clean-architecture-goal-statement/SKILL.md) のゴール記述とセルフレビューを通過させる。通過しないあいだはセクション1 に進まない。
- 実装前に `ARCHITECTURE.md` の該当禁止事項・境界を読み、今回の変更で触れる禁止番号を確認する。
- 変更範囲に応じて [`CODE_MODIFICATION_SKILLS.md`](../../references/CODE_MODIFICATION_SKILLS.md) の実装・テストスキルを選び、その `SKILL.md` に従う。
- 親エージェントが実装するときは [`use-skills-on-edit.mdc`](../../rules/use-skills-on-edit.mdc) に従って役割別サブエージェントへ委譲する（自身がサブエージェントとして起動されているときは委譲しない）。
- 振る舞い変更は該当テストと `lib/domain` のポート/DTO を同じ PR で整合させる（旧 `docs/contracts/` は廃止）。

## 2. レビュー

差分ではなく意味で確認する。違反は `ARCHITECTURE.md` の **禁止番号 × 層** で書く（重大度ラベルでの棚上げ禁止）。

- **依存方向**: `lib/domain` にフレームワーク・ORM・HTTP・具象アダプターの `new` が紛れ込んでいないか。
- **配線**: `CompositionRoot` / コンストラクタ注入が本番とテストで同一の契約か。
- **責務**: Presenter が取得・認可・本質バリデーションを握っていないか。Gateway が表示用 Hash 互換まで抱えていないか。Controller を業務分岐の主スイッチにしていないか。
- **DTO**: DTO に `ApplicationRecord` / `Relation` が載っていないか。Interactor がそれに `persisted?` / `validate!` を当てたり `ActiveRecord::*` を rescue してユースケース分岐したりしていないか。境界を跨いだあとは ID・値・エンティティ・プレゼン非依存の構造のみを運ぶ。
- **アダプター層テスト**: Gateway / Presenter / Controller のテストでユースケース網羅を主題にしていないか（**主題にしてよいのは**境界契約と E2E / 統合のみ。網羅と setup 共有は Interactor / domain テスト＋ヘルパーで行う）。
- **Concern**: `ActiveSupport::Concern` / `include …Concern` で新規にユースケース判断・ドメイン共通化を載せていないか。

## 3. レビューに対する修正

- 指摘を一度にまとめて反映する。スコープ外のついでリファクタリングはしない。
- 触れた本番コードの関連テストを [`test-quality-checklist.mdc`](../../rules/test-quality.mdc)「改修時の関連テスト棚卸し」に従って棚卸しし、削減・統合・移動を優先する。新規追加は既存で観測されていない振る舞いを表明するときのみ。

## 4. 変更の有無のチェック

**アーキテクチャゲート（1 回目・2 回目とも省略不可）**

手順・記録形式は [`ca-violation-fix-architecture-gate.mdc`](../../rules/ca-violation-fix-architecture-gate.mdc) に従う。違反があれば修正してから次へ。両方クリアした場合のみ振る舞いチェックへ進む。

**振る舞いチェック**

- **意図したファイルだけが変わっているか**: `git diff` / `git status` でスコープ外の変更がないことを確認する。
- **期待する振る舞い・出力**: 仕様・契約・表示が意図どおりか。
- **テスト**: `lib/domain` / gateway 境界 / `CompositionRoot` に触れたら [`rails-testing-workflow.mdc`](../../rules/rails-testing-workflow.mdc) に従って test-common 経由で実行する（個別 → 全体 → 遅延検知。省略不可）。

## 5. チェック結果に対する修正

問題があれば セクション3 と同様に修正し、セクション4 を再度実行する。問題なしになるまで セクション4 → セクション5（必要なら セクション2 → セクション3）を回す。

## 6. コミットと再洗い出し・終了条件

セクション1〜セクション5 が問題なしになったら外側へ戻る。

- **コミット**: セクション0 のスコープを `git add` / `git commit`。メッセージはレイヤ・禁止番号・コミット単位が追えること。`git-operational-constraints.mdc` が禁じるのは checkout / switch / reset 等であり commit は対象外。ユーザーがコミット禁止を明示したときのみ省略する。
- **push**: ユーザーが明示依頼したときのみ。
- **再洗い出し（必須）**: コミット後、**毎回**セクション0 と同様に `ARCHITECTURE.md` の規約と照らしてコードベースを調査する（解消の確認・新規逸脱の有無）。**洗い出しを省略しない。** 残件の記録はチーム運用に合わせる（専用 Markdown ファイルを置くかどうかは任意）。
- **外側ループの継続**: 洗い出しの結果、未修正の逸脱が残るなら **先頭の修正単位**を次の作業スコープに固定してセクション1 へ戻る。続行／打ち切りの二択をユーザーに問わない。「別ターン／次チャットで」「次イテレーションで」を締めにしない。同一依頼内で「修正単位 → セクション1〜セクション6」を可能な限り繰り返す。
- **止めてよい条件**: **規約と矛盾する依頼**、**無計画の違反追加**、その他 [`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc) に従うブロッカーで中断するときのみ。会話でのスコープ限定、口頭の合意、ゲート・洗い出し・`test-common` の省略の根拠にはしない。

### 修正単位の完了条件

修正単位のゴール達成と言えるのは次をすべて満たすときに限る:

1. セクション0 で固定した意図した変更が入っている。
2. 今回の差分で新たに増えた禁止事項がゼロである（新規分は番号と層で書く）。
3. 残違反は洗い出しで既に明示済みの既知項目に限る（差分で新規に入れたものを「軽微」「次イテレーションで」と言って残さない）。

「マージ阻止級ではない」「設計破綻ではない」「軽微な整理」「次イテレーションで」を完了の根拠にしない。これらの語が結論に出たら同一依頼内で セクション1 に戻る（[`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc)）。

### 外側ループの終了

次をすべて満たすときのみ終了する:

- その**直前に実行した**洗い出しで逸脱がゼロである。
- 直近の `git diff` は意図したスコープに限られ、未修正の違反を残したマージ状態にしない。
- 「最近触ったところは綺麗」「直近 PR の差分には違反なし」を終了根拠にしない。終了はリポジトリ全体の現行ファイルに対する洗い出し結果で判断する。

完了後に再び違反が出たら、新たな依頼でセクション0 から始める。コミット直後や残件ありの途中で「終了後・別セッション」を継続中断の理由にしない。

## References

- [Cursor エージェントで外側ループを繰り返すシェル](../clean-architecture-workflow-agent-loop/SKILL.md) — `workflowComplete` の機械判定（**バックログ専用ファイルには依存しない**）
- [`ARCHITECTURE.md`](../../../ARCHITECTURE.md) — 規約本体・禁止事項
- [`ca-violation-fix-architecture-gate.mdc`](../../rules/ca-violation-fix-architecture-gate.mdc) — アーキテクチャゲートの手順・記録形式
- [`rails-testing-workflow.mdc`](../../rules/rails-testing-workflow.mdc) — テスト実行・順序・遅延検知
- [`references/agent-operational-canonical.md`](references/agent-operational-canonical.md) — 本番断定・シェル（-path が無い場合は ARCHITECTURE.md とワークフロー本文を正とする）
- [`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc)
- [`use-skills-on-edit.mdc`](../../rules/use-skills-on-edit.mdc)
