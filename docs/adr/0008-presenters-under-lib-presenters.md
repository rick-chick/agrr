# ADR 0008: API / HTML Presenter を `lib/presenters/{api,html}/` に集約する

- **Status**: Superseded by [ARCHITECTURE.md → Presenters](../../ARCHITECTURE.md#presenters-app-adapters-context-presenters)
- **Date**: 2026-04-20
- **Superseded date**: 2026-05-19

## Context

`app/presenters` と `lib/presenters` の重複があった。

## Decision（当時）

API は `lib/presenters/api/`、HTML（計画系など）は `lib/presenters/html/` に統一する。

## Superseded（現行）

Presenter は `app/adapters/<context>/presenters/<usecase>_{api,html}_presenter.rb` に配置し、`forms/` / `view_models/` / `mappers/` を同階層に持つ。`lib/presenters/{api,html}/` は legacy として廃止済み。配置・命名規約の詳細は [ARCHITECTURE.md → Naming and placement conventions](../../ARCHITECTURE.md#naming-and-placement-conventions)。

## Consequences（当時）

コントローラの定数参照を `Presenters::Html::...` 等に揃える。

## Alternatives considered

`app/presenters` に HTML のみ残す — 契約と不一致のため却下。
