# ADR 0001: lib/domain 全 14 リソースへの Clean Architecture 適用

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

API・HTML 双方でドメインルールとインフラを分離し、テストと変更に強い構造が必要だった。

## Decision

`lib/domain/<resource>/` に entities / interactors / ports / dtos / gateways を置き、framework 依存のアダプタ（gateway 実装 / presenter / form / view_model / mapper）は `app/adapters/<resource>/` で実装する。配置・命名の詳細は [ARCHITECTURE.md → Naming and placement conventions](../../ARCHITECTURE.md#naming-and-placement-conventions)。

> **Note**: 当 ADR 採択時は `lib/adapters/<resource>/` および `app/gateways/agrr/` を実装場所としていたが、後に `app/adapters/<context>/` に統一する判断を行った（[ARCHITECTURE.md](../../ARCHITECTURE.md)）。legacy 配置は廃止済み。

## Consequences

一貫した境界と契約駆動開発が可能。新規機能は Interactor 起点で追加する。

## Alternatives considered

サービスオブジェクトのみに集約する案は却下（責務肥大とテスト困難）。
