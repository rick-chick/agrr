# ADR 0007: フロントエンドを domain / usecase / adapters / infrastructure の 4 層に整える

- **Status**: Proposed（T-053 で `infrastructure/` へ集約）
- **Date**: 2026-04-20

## Context

`services/` 直下に横断関心事とリソース固有が混在している。

## Decision

HTTP・認証・UI 横断を `frontend/src/app/infrastructure/` に移し、リソース別 helper は `services/<feature>/` に限定する。

## Consequences

import パス変更が大きいため専用 PR と全テストが必要。

## Alternatives considered

現状の `services/` flat — スケールに不利。
