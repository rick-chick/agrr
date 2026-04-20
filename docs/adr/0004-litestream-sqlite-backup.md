# ADR 0004: Litestream による SQLite レプリカ

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

マネージド RDB なしでバックアップとリストア可能性が必要。

## Decision

本番プライマリ SQLite を Litestream で GCS 等へ継続レプリケートする。

## Consequences

バックアップ手順・復旧演習を運用ドキュメントに含める。

## Alternatives considered

RDS / Cloud SQL — コストと移行コストのため現段階では採用しない。
