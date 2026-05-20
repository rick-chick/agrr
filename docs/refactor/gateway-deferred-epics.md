# ゲートウェイ負債 — スコープ外エピック（別バックログ）

本ドキュメントは、**Crop / InteractionRule** の縦スライスで解消したゲートウェイ負債のうち、**意図的にスコープ外**とした追跡用エピックを列挙する。実装は `docs/ca-violations-backlog.md` §F と照合し、**1 BC = 1 変更セット**で進める。

## 1. Gateway `user` シグネチャの統一（Farm / Fertilize / Pest 等）

- **現状**: `user` / `user_id:` / `access_filter:` のみのメソッドが混在するゲートウェイがある。
- **目標**: [ARCHITECTURE.md](../ARCHITECTURE.md) の Gateway boundary に従い、公開メソッドの認可主体は原則 **`Domain::Shared::Dtos::UserDto`**。永続で AR が必要なときは **アダプター内部のみ**。
- **注意**: 認可不要の読み取り専用 API は `user` を取らない設計のままでよいが、**戻り型の AR 越境**は別ラベル（§F）で解消する。

## 2. §F に残る BC（Pest / Pesticide / AgriculturalTask / Field 等）

- `find_authorized_model_*` の除去、`build_blank_*`、`pest_record:` 経由の AR、`find_model` など §F 表の未処理行を **bounded context ごと**に消化する。

## 3. agrr.core（Python）ゲートウェイと Rails ドメインの境界

- **現状**: リポジトリ **agrr.core**（Python）側の `CropGateway` / `PestGateway` / `InteractionRuleGateway` は **認可主体なし**のデータ取得 IF として別系統。
- **目標**: 名称衝突や「同一契約」と誤解されないよう、`ARCHITECTURE.md` または本リポの `docs/contracts` に **1 段落**で境界を明記する（完全な IF 名の統一は必須としない）。

## 4. フェーズ C 残り（作物以外・作物の残 AR 経路）

- `CropGateway#each_reference_crop_for_entry_schedule` の AR yield、`find_user_non_reference_crop_record` の Adapter 専用化の徹底、`create_for_user` / `update_for_user` の Command DTO 化など。詳細は `ca-violations-backlog.md` のフェーズ C 節（2026-05-10: エントリ yield と Crop 永続は対応済み）。
