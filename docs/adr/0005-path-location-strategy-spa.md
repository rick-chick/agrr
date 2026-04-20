# ADR 0005: Angular を PathLocationStrategy に統一する

- **Status**: Accepted
- **Date**: 2026-04-20

## Context

Hash URL は共有・計測・CDN ルーティングで不利。

## Decision

`HashLocationStrategy` を外し、URL map で未一致パスを `/index.html` にフォールバックする（`scripts/agrr-frontend-url-map-simple.yaml`）。

## Consequences

ディープリンクのリロードが CDN 設定に依存する。変更時は URL map を必ず検証する。

## Alternatives considered

Hash を維持 — 却下。
