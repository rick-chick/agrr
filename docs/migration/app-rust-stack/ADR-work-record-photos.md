# ADR: 作業記録写真の二層ストレージ

## Status

Accepted (2026-07-14)

親 issue: #222。Backend 実装: #223（PR #227–#228）、登録 UI: #224（PR #229）。残タスク: #225（実績履歴閲覧 UI）、#226（削除 undo・ストレージ整合性）。

## Context

作業記録（`work_records`）に写真を添付し、実績履歴で確認できるようにする。当初 `docs/design/work-record-gui-plan.md` §6 では非スコープだったが、モバイル畑作業での実績記録ニーズにより v1 を追加する。

既存インフラは GCP（Cloud Run + Litestream GCS + 気象 GCS）。予測気象の二層化（`ADR-predicted-weather-gcs-two-layer.md`）と同様、SQLite はメタデータのみ、画像本体はオブジェクトストレージに置く。

## Decision

### 1. ストレージ: GCS（既存 adapter 拡張）

- **選定**: GCS。`agrr-adapters-gcs` の `WorkRecordPhotoGcsStore` を追加。S3 / 汎用 trait 抽象は v1 では採用しない。
- **根拠**: 既存 IAM・`GcsObjectClient` パターン流用、追加クラウド不要。
- **本番**: `WORK_RECORD_PHOTO_STORAGE=gcs`、`GCS_WORK_RECORD_PHOTO_BUCKET`（未設定時 `GCS_BUCKET`）。
- **ローカル dev**: `WORK_RECORD_PHOTO_LOCAL_ROOT` または `WEATHER_DATA_LOCAL_ROOT`、デフォルト `storage/work_record_photos`。

### 2. メタスキーマ: `work_record_photos`（V14）

| カラム | 用途 |
|--------|------|
| `id` | PK |
| `work_record_id` | FK → `work_records` ON DELETE CASCADE |
| `cultivation_plan_id` | FK → `cultivation_plans`（認可・キー生成用） |
| `storage_key` | オブジェクトパス |
| `content_type` | MIME |
| `byte_size` | サイズ検証用 |
| `position` | 表示順（0 始まり、ユニーク `(work_record_id, position)` WHERE NOT NULL） |
| `status` | `pending` / `completed` |
| `original_filename` | 任意（UX） |
| `created_at` / `updated_at` | |

**v1 で採用しない**: `width` / `height` 列、sha256 重複排除、サムネイル別オブジェクト、EXIF（GPS）除去（クライアント JPEG 再エンコードで間接的に除去）。

オブジェクトキー: `work_record_photos/{plan_id}/{work_record_id}/{nanos}.{ext}`

### 3. 枚数・ファイル制約

| 項目 | 値 | 実装 |
|------|-----|------|
| 枚数上限 | 3 枚/記録 | `work_record_photo_policy::MAX_PHOTOS_PER_RECORD` |
| 最大サイズ | 5 MB/枚 | `MAX_BYTE_SIZE` |
| MIME | `image/jpeg`, `image/png`, `image/webp` | `content_type_allowed` |
| HEIC | v1 非対応 | — |
| クライアントリサイズ | 長辺 1920px、JPEG quality 0.85 | `resize-work-record-photo.ts` |

0 枚許容（任意添付）。編集時の追加・削除は登録シート UI（#224）で対応。

### 4. アップロード方式: API 経由二段階（presigned 直送は v1 非採用）

```
upload_init → PUT .../photos/{id}/content → upload_complete
```

- `upload_init`: メタ行 `pending` 作成、API 相対 `upload_url` 返却（`upload_method: PUT`、TTL 600 秒）。
- `PUT .../content`: サーバーが GCS / ローカル FS に書き込み（Cloud Run 経由）。
- `upload_complete`: オブジェクト存在・サイズ検証、`status=completed`、`position` 割当。

**v1 で採用しない**: GCS/S3 への presigned 直送（CORS・孤児オブジェクト清掃の複雑さ）。将来の帯域削減候補として #226 以降で検討可。

### 5. アクセス制御・URL

- オブジェクトは **private**（GCS / ローカル FS）。
- 閲覧: API `GET .../photos/{id}/content`（`private_plan_access` 認可）。`GET work_records` の `photos[].url` はこのエンドポイント。
- CDN キャッシュ: v1 非対象（セッション認可のため）。
- 読み取り TTL 定数 `READ_URL_TTL_SECS`（900 秒）は将来 presign 用に予約；現行は API 経由のため未使用。

### 6. Domain / API 形状

`ARCHITECTURE.md` に従い 1 アクション = 1 Interactor + Presenter:

| エンドポイント | Interactor |
|----------------|------------|
| `POST .../photos/upload_init` | `WorkRecordPhotoUploadInitInteractor` |
| `POST .../photos/{id}/upload_complete` | `WorkRecordPhotoUploadCompleteInteractor` |
| `DELETE .../photos/{id}` | `WorkRecordPhotoDestroyInteractor` |
| `GET work_records` embed | `load_photos_json_for_records`（一覧用） |

Gateway: `WorkRecordPhotoGateway`（SQLite メタ）、`WorkRecordPhotoObjectStoreGateway`（GCS/FS 本体）。

### 7. 削除・undo（v1 範囲とフォローアップ）

| 操作 | v1 |
|------|-----|
| 作業記録削除 | メタ行は FK CASCADE で削除。オブジェクトは Interactor 経由で即削除 |
| 作業記録削除 undo | **未対応** → #226 |
| 計画削除 undo | 添付メタ snapshot **未対応** → #226 |
| 写真のみ削除（編集時） | 対応済み（undo 対象外） |
| presign 後未 complete の孤児 | `pending` 行 + オブジェクト未作成のため孤児リスク低。TTL 清掃ジョブは #226 |

### 8. UI/UX スコープ

| 画面 | v1 |
|------|-----|
| 登録シート | 対応済み（#224）: カメラ/ギャラリー、プレビュー、枚数上限、削除 |
| 実績履歴リスト | **未実装** → #225 |
| 編集シート | 登録シートと同一コンポーネントで対応 |
| 今日の作業 | v1 非スコープ |

### 9. コスト・クォータ

- ユーザー/計画あたりのストレージ上限: v1 なし（枚数×サイズで間接制限）。
- Litestream: メタのみ SQLite のため影響小。オブジェクト課金は GCS 別途。

### 10. ローカル dev / テスト

- FS ミラー: `WORK_RECORD_PHOTO_LOCAL_ROOT`（気象 `GcsObjectClient` パターン）。
- `agrr-domain` unit tests、`agrr-adapters-sqlite` integration、`agrr-r4-contract` 契約テスト。
- E2E ファイルアップロード: Playwright 対応は将来。

## Consequences

- Cloud Run 経由 PUT のため大容量・多数同時アップロード時は帯域・タイムアウトに注意。モバイル向けクライアントリサイズで緩和。
- #225（実績履歴サムネイル）・#226（undo snapshot / 孤児 GC）が残る。親 #222 は本 ADR 記録後に close 可。
- S3 要望は v1 では GCS に統一。マルチクラウドが必要になった場合は trait 抽象を別 ADR で検討。

## 参照

- `crates/agrr-migrate/migrations/schema/V14__work_record_photos.sql`
- `crates/agrr-domain/src/work_record/policies/work_record_photo_policy.rs`
- `crates/agrr-adapters-gcs/src/work_record_photo_store_gateway.rs`
- `crates/agrr-server/src/work_record_photos.rs`
- `frontend/src/app/domain/plans/work-record-photo.constants.ts`
- `docs/migration/app-rust-stack/ADR-predicted-weather-gcs-two-layer.md`
