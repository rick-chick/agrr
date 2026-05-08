# 作物スケジュール（エントリ）— まき／植えと CropStage の対応

**ステータス**: 実装準拠  
**関連**: [crop_schedule_entry_product_requirements.md](./crop_schedule_entry_product_requirements.md)

## 方針（案B 最小版）

DB に「播種」「定植」ラベルがないため、コード [`Domain::CultivationPlan::Interactors::EntrySchedule::StageRoleResolver`](../../lib/domain/cultivation_plan/interactors/entry_schedule/stage_role_resolver.rb) で次の規約を採用する。

### まき（sowing）に相当するステージ

- **`crop_stages` を `order` 昇順で並べた先頭1件**を「まき／育苗の最初のタイミング」の代表とする。
- 作物によっては先頭が「育苗期」などになるが、**一覧・帯のラベルは UI で「種をまく目安」等の口語**に統一可能。

### 植え（transplanting）に相当するステージ

1. 名前が **`定植` または `植え付` を含む**ステージを優先（正規表現 `/定植|植え付/`）。
2. 見つからない場合は **`order` が2番目**のステージ（`order` 昇順で offset 1）。

### 代表作物での期待

| 作物例 | 先頭ステージ | 定植相当 |
|--------|----------------|----------|
| トマト（参照マスタ） | 育苗期 (order 1) | 定植期 (order 2) または名前マッチ |

## 将来拡張（案A）

`crop_stage_roles` テーブル等で **crop_id + stage_id + role** を持ち、上記ルールを上書きする。
