# ADR 0001: lib/domain 全 14 リソースへの Clean Architecture 適用

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

API・HTML 双方でドメインルールとインフラを分離し、テストと変更に強い構造が必要だった。

## Decision

`lib/domain/<resource>/` に entities / interactors / ports / dtos / gateways を置き、アダプタは `lib/adapters`・`app/gateways` で実装する。

## Consequences

一貫した境界と契約駆動開発が可能。新規機能は Interactor 起点で追加する。

## Alternatives considered

サービスオブジェクトのみに集約する案は却下（責務肥大とテスト困難）。
