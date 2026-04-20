# ADR 0006: agrr Gateway を v2（AgrrService 経由）に統一する

- **Status**: Proposed（移行手順は `docs/planning/agrr_gateway_v2_migration.md`）
- **Date**: 2026-04-20

## Context

`BaseGateway` v1 と `BaseGatewayV2` の併存で例外型と実装が二重化している。

## Decision

v2 実装を唯一の `Agrr::BaseGateway` とし、v1 ファイルを削除する。

## Consequences

ジョブ・concern の `rescue` 先を一本化する必要がある。

## Alternatives considered

v1 を薄いラッパとして残す — 却下（負債継続）。
