# E2E smoke（Playwright + Angular + agrr-server）

正常系の**到達・読込完了・主要操作**を簡潔に検証する。ピクセル回帰は行わない。

## 前提

1. `.cursor/skills/dev-docker/scripts/load-reference-data-host.sh`（または `load-reference-data.sh`）
2. 別ターミナル: `.cursor/skills/dev-docker/scripts/up.sh` または `host-rust-stack.sh`
3. frontend で:

```bash
npm run test:e2e:smoke
```

`E2E_CAPTURE_DEV_SESSION=1` により globalSetup が Rust の `/auth/test/mock_login_as/developer` で `e2e/.auth/dev-session.json` を生成する。`E2E_STRANGLER=1` で Playwright は Rails を起動せず nginx :3000 → agrr-server :8080 を利用する。

## API ベースライン（項目 5）

`beforeAll` で `ensureE2eBaseline()`（[`../fixtures/ensure-e2e-baseline.ts`](../fixtures/ensure-e2e-baseline.ts)）が dev セッション経由で次を idempotent に確保する:

| 種別 | 表示名プレフィックス |
|------|---------------------|
| 7 マスタ（`MASTER_SEGMENTS` 全種） | `E2E Baseline` |
| private Plan | `E2E Baseline Plan`（`/api/v1/plans` が空のときのみ POST） |

`loadResolvedCaptureIds` → `ensureE2eBaseline` → `loadResolvedCaptureIds` の順で `resolvedCaptureIds` を更新し、マスタ detail/edit の `test.skip`（`no * record`）を減らす。

**触らないもの**: 参照農場（公開 wizard・作業目安）、`publicPlanId` probe、ガント中身の生成。農場 UI CRUD 完走は **farms のみ**（[`operation-smoke.spec.ts`](operation-smoke.spec.ts) の `master farms: create, list, edit, delete`）。ベースライン行は削除しない。

## スペック

| ファイル | 内容 |
|----------|------|
| `route-smoke.spec.ts` | `route-manifest.json` 全ルート: 正しいホスト表示・ローディング解消・`.error-message` 非表示 |
| `operation-smoke.spec.ts` | ホーム CTA、ナビ、公開 wizard（farm-size → select-crop）、問い合わせ、**farms UI CRUD**、マスタ list/new/detail/edit、ガント UI、作業目安一覧→詳細、API キー、天気、作業予定 D&D など |

`E2E_CAPTURE_DEV_SESSION` 未設定時は smoke は skip（`route-manifest-coverage` 等は `npm run test:e2e` で実行可）。未ログイン向けに `login` / 404 のみ別 describe で実行。

## 既知の skip（データ依存）

| 理由 | 依存 |
|------|------|
| `no public farms in dev DB` | 参照農場 fixture |
| `no farms for entry schedule` / `no entry schedule crops in grid` | 参照農場 + 目安 API |
| `plan has no gantt data` / `no task schedule items` | 計画の最適化・スケジュールデータ |
| `user farm limit reached (max 4)` | ユーザー農場 4 件上限（farms UI CRUD） |
| `publicPlanId` 未解決 | route-smoke の公開プラン URL は probe または placeholder |

`buildResolvedCaptureIds` は各マスタ・private Plan で **`E2E Baseline` プレフィックス一致 id を優先**し、無ければ一覧先頭にフォールバックする（[`../shared/baseline-ids.ts`](../shared/baseline-ids.ts)）。
