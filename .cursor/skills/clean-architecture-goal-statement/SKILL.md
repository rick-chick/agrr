---
name: clean-architecture-goal-statement
description: Forces a written, ARCHITECTURE.md-aligned goal before implementing a use case. Use before starting any change that touches lib/domain, gateway boundaries, lib/composition_root.rb, app/controllers/api, or frontend usecase/adapters. Output is a short statement naming domain behavior, edge concretes, and the prohibition (1–30) being addressed; the agent reviews it against ARCHITECTURE.md before writing code.
---

# Clean Architecture ゴール記述（着手前）

実装に先立ち、ARCHITECTURE.md と整合するゴールを **書面で固定**するためのゲート。1 イテレーション = 1 ユースケース。書けない・自己レビューを通らないなら実装しない。

## いつ使うか

- `clean-architecture-violation-fix-workflow` のセクション 0 でスコープを固定したあと、セクション 1 の実装より前。
- 新規実装・機能追加でも、`lib/domain` / Gateway 境界 / `lib/composition_root.rb` / `app/controllers/api/` / `frontend/src/app/usecase/` / `frontend/src/app/adapters/` に触れるとき。

## 書く内容

各項目 1〜2 行で、対象ユースケースに固有の事実を書く。一般論で埋めない。

1. **対象ユースケース**: 名前と現状の入口（コントローラ／ジョブ／コンポーネントのアクション）。
2. **ドメインに残す振る舞い**: Interactor の判断、Output Port が返す DTO のフィールド、Gateway interface のメソッド。
3. **エッジに残す具象**: Controller / コンポーネントが組み立てる入力 DTO、Presenter が担う HTTP・HTML・View State の形、Gateway 実装が触れる ActiveRecord / HTTP / 時刻 / I/O。
4. **取り除く・移す対象**: 現状の境界違反（mixin、`rescue`、`render`、AR 直叩き、ドメイン内 `CompositionRoot` 呼び出し、Presenter での再取得 など）。
5. **対応する禁止条項**: ARCHITECTURE.md `## Prohibited practices` の 1〜30 から該当番号を 1 つ以上挙げる（複数可、不特定の「全部」は不可）。
6. **完了の客観条件**: 実装後に grep やファイル一覧で確認できる粒度で書く。例: 「Controller が DTO 構築 + Interactor 呼び出し + Presenter 注入だけになる」「`render` / `redirect_to` / `respond_to` / AR / `rescue` がコントローラに残らない」「Presenter から `CompositionRoot` 呼び出しが消える」。

## セルフレビュー

書いた内容を ARCHITECTURE.md の `## What we require` と `## Prohibited practices` 1〜30 に突き合わせる。次のいずれかに当てはまるなら書き直す。

- ドメインに残す振る舞いの記述が、ファイル移動・継承化・mixin 置換の宣言にとどまり、判断や DTO の中身が出ていない。
- エッジに残す具象に、業務ルール・認可・条件分岐の判断が混ざっている。
- 完了条件が「テストが通る」「concern を消した」「ベースクラスに移した」など、境界の意味を測れない表現になっている。
- 対応する禁止条項が選べない、または対象差分との対応が示せない。

## 中断・継続

- 書けない、またはセルフレビューを通らない場合は実装しない。別のユースケースに切り替える、規約と矛盾するならユーザーへ報告する（[`no-convenience-tech-debt.mdc`](../../rules/no-convenience-tech-debt.mdc)）。
- 通過したゴール記述は、コミットメッセージの根拠およびワークフローのセクション 4 ゲート記録の前提として参照する。

## References

- [ARCHITECTURE.md](../../../ARCHITECTURE.md)
- [clean-architecture-violation-fix-workflow/SKILL.md](../clean-architecture-violation-fix-workflow/SKILL.md)
- [no-convenience-tech-debt.mdc](../../rules/no-convenience-tech-debt.mdc)
