---
name: clean-architecture-goal-statement
description: Forces a written, ARCHITECTURE.md-aligned goal before implementing a use case. Use before starting any change that touches crates/agrr-domain, gateway boundaries, crates/agrr-server composition, or frontend usecase/adapters. Output is a short statement naming domain behavior, edge concretes, and the prohibition (1–39) being addressed; the agent reviews it against LAYER-RULES before writing code.
---

# Clean Architecture ゴール記述（着手前）

実装に先立ち、ARCHITECTURE.md / LAYER-RULES と整合するゴールを **書面で固定**するためのゲート。1 イテレーション = 1 ユースケース。書けない・自己レビューを通らないなら実装しない。

## いつ使うか

- `clean-architecture-violation-fix-workflow` のセクション 0 でスコープを固定したあと、セクション 1 の実装より前。
- 新規実装・機能追加でも、`crates/agrr-domain` / Gateway 境界 / `crates/agrr-server` composition / `frontend/src/app/usecase/` / `frontend/src/app/adapters/` に触れるとき。

## 書く内容

各項目 1〜2 行で、対象ユースケースに固有の事実を書く。一般論で埋めない。

1. **対象ユースケース**: 名前と現状の入口（Axum handler／ジョブ／コンポーネントのアクション）。
2. **ドメインに残す振る舞い**: Interactor の判断、Output Port が返す DTO のフィールド、Gateway trait のメソッド。
3. **エッジに残す具象**: Handler / コンポーネントが組み立てる入力 DTO、Presenter が担う HTTP・View State の形、Gateway 実装が触れる SQLite / HTTP / 時刻 / I/O。
4. **取り除く・移す対象**: 現状の境界違反（隠れ取得、`rescue`、ドメイン内 composition 呼び出し、Presenter での再取得 など）。
5. **対応する禁止条項**: [`docs/architecture/LAYER-RULES.md`](../../../docs/architecture/LAYER-RULES.md) の ❌ 条項から該当番号を 1 つ以上挙げる（ゲートでは 1〜39。複数可、「全部」は不可）。
6. **完了の客観条件**: 実装後に grep やファイル一覧で確認できる粒度で書く。

## セルフレビュー

書いた内容を LAYER-RULES の `## What we require` と ❌ 禁止条項（1〜39）に突き合わせる。次のいずれかに当てはまるなら書き直す。

- ドメインに残す振る舞いの記述が、ファイル移動の宣言にとどまり、判断や DTO の中身が出ていない。
- エッジに残す具象に、業務ルール・認可・条件分岐の判断が混ざっている。
- 完了条件が「テストが通る」など、境界の意味を測れない表現になっている。
- 対応する禁止条項が選べない、または対象差分との対応が示せない。

## 中断・継続

- 書けない、またはセルフレビューを通らない場合は実装しない（[`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc)）。
- 通過したゴール記述は、コミットメッセージの根拠およびワークフローのセクション 4 ゲート記録の前提として参照する。

## References

- [ARCHITECTURE.md](../../../ARCHITECTURE.md)
- [docs/architecture/LAYER-RULES.md](../../../docs/architecture/LAYER-RULES.md)
- [clean-architecture-violation-fix-workflow/SKILL.md](../clean-architecture-violation-fix-workflow/SKILL.md)
