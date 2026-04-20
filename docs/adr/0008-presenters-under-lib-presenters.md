# ADR 0008: API / HTML Presenter を `lib/presenters/{api,html}/` に集約する

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

`app/presenters` と `lib/presenters` の重複があった。

## Decision

API は `lib/presenters/api/`、HTML（計画系など）は `lib/presenters/html/` に統一する。

## Consequences

コントローラの定数参照を `Presenters::Html::...` 等に揃える。

## Alternatives considered

`app/presenters` に HTML のみ残す — 契約と不一致のため却下。
