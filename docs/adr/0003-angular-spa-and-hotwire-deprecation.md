# ADR 0003: フロントを Angular 21 SPA に一本化し Hotwire を段階撤去する

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

新機能は Angular で実装済みだが、計画 Gantt 等に HTML + Stimulus が残存する。

## Decision

新規 UI は `frontend/` のみ。既存 Rails View は `docs/planning/hotwire_removal_plan.md` に従い順次置換後、依存を削除する。

## Consequences

Phase 4（T-040〜T-043）までルート JS バンドルと Gem が併存する。

## Alternatives considered

Hotwire を恒久併用 — 却下（二重メンテナンス）。
