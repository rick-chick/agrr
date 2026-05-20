# ADR 0002: 本番を GCP Cloud Run + GCS + Cloud CDN とする

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

スケールと運用コスト、SQLite + Litestream との整合が必要。

## Decision

Rails API / HTML は Cloud Run、Angular 静的資産は GCS、エッジは Cloud CDN。URL map で `/api` 等をバックエンドへ振り分ける。

## Consequences

デプロイは `.cursor/skills/deploy-server/scripts/gcp-deploy.sh` / `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh` に集約。

## Alternatives considered

AWS S3 + CloudFront は過去構成として文書のみ残す。
