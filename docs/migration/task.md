## 必須（8項目）
1. `plowing` - 耕耘
2. `base_fertilization` - 基肥
3. `seeding` - 播種
4. `transplanting` - 定植
5. `watering` - 灌水
6. `weeding` - 除草
7. `harvesting` - 収穫
8. `shipping_preparation` - 出荷準備

### 条件付き必須（使用する場合、毎シーズン必要）
9. `mulching` - マルチング
10. `tunnel_setup` - トンネル設置
11. `support_structure_setup` - 支柱立て
12. `net_installation` - 防虫ネット張り
13. `thinning` - 間引き（直まき作物）
14. `pruning` - 剪定（果菜類）
15. `training` - 誘引（果菜類）
16. `grading` - 規格選別
17. `packaging` - 箱詰め・袋詰め

## 参照作物（日本）

マイグレーション `20251018075019_seed_japan_reference_data.rb` から参照される日本の参照作物は以下の15種類です：

1. かぼちゃ（西洋かぼちゃ）
2. キャベツ（春キャベツ）
3. キュウリ（白イボ）
4. ジャガイモ（男爵）
5. 大根（青首大根）
6. とうもろこし（スイートコーン）
7. トマト（大玉）
8. ナス（千両二号）
9. ニンジン（五寸ニンジン）
10. 白菜（結球白菜）
11. ピーマン（京みどり）
12. ブロッコリー（一般）
13. ほうれん草（一般）
14. レタス（結球レタス）
15. 玉ねぎ（黄玉ねぎ）

各作物は `db/fixtures/reference_crops.json` から読み込まれ、`region='jp'`, `is_reference=true` として登録されます。

## マイグレーション作成時の確認項目

各タスクについて、以下の属性を確認する必要があります：

### AgriculturalTaskモデルの属性

- `name` (string, required): タスク名。一意性が必要（参照タスクは名前で一意、ユーザー所有はユーザー内で一意）
- `description` (text, nullable): タスクの説明文
- `time_per_sqm` (float, nullable): 単位面積（㎡）あたりの所要時間（時間/㎡）
- `weather_dependency` (string, nullable): 天候依存度。値: 'low', 'medium', 'high'
- `required_tools` (text, nullable): 必要な工具。JSON配列として保存（例: `["スコップ", "移植ごて"]`）
- `skill_level` (string, nullable): スキルレベル。値: 'beginner', 'intermediate', 'advanced'
- `is_reference` (boolean, default: true): 参照タスクフラグ。マスタデータはtrue
- `user_id` (integer, nullable): ユーザーID。参照タスクの場合はnull
- `region` (string, nullable): 地域コード。'jp', 'us', 'in' など

### 各タスクの確認項目

#### 1. `plowing` - 耕耘
- **name**: `plowing`
- **description**: "土を耕して柔らかくする作業"
- **time_per_sqm**: 0.05 時間/㎡（手作業の場合）
- **weather_dependency**: 'medium' または 'high'（土が乾いている必要があるため）
- **required_tools**: `["スコップ", "クワ", "鍬"]` など（重機は使用しない）
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 2. `base_fertilization` - 基肥
- **name**: `base_fertilization`
- **description**: "植え付け前に土に混ぜ込む肥料"
- **time_per_sqm**: 0.01 時間/㎡
- **weather_dependency**: 'low'（天候に依存しない）
- **required_tools**: `["スコップ", "肥料"]` など
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 3. `seeding` - 播種
- **name**: `seeding`
- **description**: "種をまく作業"
- **time_per_sqm**: 0.005 時間/㎡（種まきは速い）
- **weather_dependency**: 'medium'（適度な天候が必要）
- **required_tools**: `["種", "まき溝切り器"]` など（重機は使用しない）
- **skill_level**: 'beginner' または 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（直まきする作物）
  - [x] かぼちゃ
  - [ ] キャベツ（通常は苗を定植）
  - [ ] キュウリ（通常は苗を定植）
  - [ ] ジャガイモ（種イモ）
  - [x] 大根
  - [x] とうもろこし
  - [ ] トマト（通常は苗を定植）
  - [ ] ナス（通常は苗を定植）
  - [x] ニンジン
  - [ ] 白菜（通常は苗を定植）
  - [ ] ピーマン（通常は苗を定植）
  - [ ] ブロッコリー（通常は苗を定植）
  - [x] ほうれん草
  - [ ] レタス（通常は苗を定植）
  - [ ] 玉ねぎ（通常はセット球か苗を定植）

#### 4. `transplanting` - 定植
- **name**: `transplanting`
- **description**: "苗を植え付ける作業"
- **time_per_sqm**: 0.02 時間/㎡（苗植えは時間がかかる）
- **weather_dependency**: 'medium'（適度な天候が必要）
- **required_tools**: `["苗", "移植ごて"]` など
- **skill_level**: 'beginner' または 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（苗を植える作物）
  - [x] かぼちゃ（苗を定植することもある）
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ（種イモ植え）
  - [ ] 大根（通常は直まき）
  - [ ] とうもろこし（通常は直まき）
  - [x] トマト
  - [x] ナス
  - [ ] ニンジン（通常は直まき）
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [ ] ほうれん草（通常は直まき）
  - [x] レタス
  - [x] 玉ねぎ（セット球か苗を定植）

#### 5. `watering` - 灌水
- **name**: `watering`
- **description**: "作物に水を与える作業"
- **time_per_sqm**: 0.01 時間/㎡（面積による）
- **weather_dependency**: 'high'（雨が降っている場合は不要）
- **required_tools**: `["ホース", "散水器"]` など
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 6. `weeding` - 除草
- **name**: `weeding`
- **description**: "雑草を取り除く作業"
- **time_per_sqm**: 0.03 時間/㎡（手作業の場合）
- **weather_dependency**: 'medium'（土が湿っていると取りやすい）
- **required_tools**: `["鎌", "草取りフォーク"]` など（重機は使用しない）
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 7. `harvesting` - 収穫
- **name**: `harvesting`
- **description**: "作物を収穫する作業"
- **time_per_sqm**: 0.05 時間/㎡（作物による、手作業の場合）
- **weather_dependency**: 'medium'（雨の日は避ける場合が多い）
- **required_tools**: `["ハサミ", "収穫かご"]` など
- **skill_level**: 'beginner' または 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 8. `shipping_preparation` - 出荷準備
- **name**: `shipping_preparation`
- **description**: "出荷前の準備作業（洗浄、選別など）"
- **time_per_sqm**: 0.05 時間/㎡（手作業の場合）
- **weather_dependency**: 'low'
- **required_tools**: `["バケツ", "選別用かご", "ブラシ"]` など（重機は使用しない）
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 9. `mulching` - マルチング
- **name**: `mulching`
- **description**: "マルチシートを敷く作業"
- **time_per_sqm**: 0.01 時間/㎡
- **weather_dependency**: 'medium'（風の強い日は困難）
- **required_tools**: `["マルチシート", "マルチ押さえ"]` など
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（マルチングが必要な作物）
  - [x] かぼちゃ
  - [ ] キャベツ（寒冷地では有効だが一般的ではない）
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根（特に秋冬作）
  - [ ] とうもろこし（一般的ではない）
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜（秋冬作で有効）
  - [x] ピーマン
  - [ ] ブロッコリー（一般的ではない）
  - [ ] ほうれん草（一般的ではない）
  - [ ] レタス（一般的ではない）
  - [x] 玉ねぎ

#### 10. `tunnel_setup` - トンネル設置
- **name**: `tunnel_setup`
- **description**: "トンネル支柱を設置する作業"
- **time_per_sqm**: 0.02 時間/㎡
- **weather_dependency**: 'medium'（風の強い日は困難）
- **required_tools**: `["トンネル支柱", "ビニール"]` など
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（トンネル栽培が必要な作物）
  - [ ] かぼちゃ（一般的ではない）
  - [x] キャベツ（寒冷地、春先の保温）
  - [x] キュウリ（早熟栽培）
  - [ ] ジャガイモ（一般的ではない）
  - [x] 大根（秋冬作、早熟栽培）
  - [ ] とうもろこし（一般的ではない）
  - [x] トマト（早熟栽培）
  - [x] ナス（早熟栽培）
  - [x] ニンジン（早熟栽培）
  - [x] 白菜（早熟栽培、秋まき）
  - [x] ピーマン（早熟栽培）
  - [x] ブロッコリー（早熟栽培、秋まき）
  - [x] ほうれん草（秋冬作）
  - [x] レタス（早熟栽培、秋冬作）
  - [x] 玉ねぎ（秋まき、越冬用）

#### 11. `support_structure_setup` - 支柱立て
- **name**: `support_structure_setup`
- **description**: "支柱を立てて作物を支える作業"
- **time_per_sqm**: 0.015 時間/㎡
- **weather_dependency**: 'low'
- **required_tools**: `["支柱", "結束バンド"]` など
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（支柱が必要な作物：つる性や背が高い作物）
  - [x] かぼちゃ（つる性、地這いでも良いが支柱で立体的に）
  - [ ] キャベツ（通常不要）
  - [x] キュウリ（つる性、必須）
  - [ ] ジャガイモ（通常不要）
  - [ ] 大根（通常不要）
  - [ ] とうもろこし（背が高いが通常は支柱不要）
  - [x] トマト（背が高い、支柱必要）
  - [x] ナス（背が高い、支柱必要）
  - [ ] ニンジン（通常不要）
  - [ ] 白菜（通常不要）
  - [x] ピーマン（背が高い、支柱必要）
  - [ ] ブロッコリー（通常不要）
  - [ ] ほうれん草（通常不要）
  - [ ] レタス（通常不要）
  - [ ] 玉ねぎ（通常不要）

#### 12. `net_installation` - 防虫ネット張り
- **name**: `net_installation`
- **description**: "防虫ネットを設置する作業"
- **time_per_sqm**: 0.015 時間/㎡
- **weather_dependency**: 'medium'（風の強い日は困難）
- **required_tools**: `["防虫ネット", "ネット押さえ"]` など
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（害虫の被害を受けやすい作物）
  - [x] かぼちゃ（ウリハムシなど）
  - [x] キャベツ（コナガ、アオムシなど、重要）
  - [x] キュウリ（ウリハムシ、アブラムシなど）
  - [ ] ジャガイモ（一般的ではない）
  - [x] 大根（アブラムシ、コナガなど）
  - [ ] とうもろこし（一般的ではない）
  - [ ] トマト（一般的ではない）
  - [ ] ナス（一般的ではない）
  - [ ] ニンジン（一般的ではない）
  - [x] 白菜（コナガ、アオムシなど、重要）
  - [ ] ピーマン（一般的ではない）
  - [x] ブロッコリー（コナガ、アオムシなど）
  - [ ] ほうれん草（一般的ではない）
  - [ ] レタス（一般的ではない）
  - [ ] 玉ねぎ（一般的ではない）

#### 13. `thinning` - 間引き
- **name**: `thinning`
- **description**: "過密な苗を間引く作業"
- **time_per_sqm**: 0.01 時間/㎡
- **weather_dependency**: 'low'
- **required_tools**: `["ハサミ"]` など
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（直まきで間引きが必要な作物）
  - [x] かぼちゃ（直まきの場合）
  - [ ] キャベツ（通常は苗を定植）
  - [ ] キュウリ（通常は苗を定植）
  - [ ] ジャガイモ（通常不要）
  - [x] 大根（直まき、重要）
  - [x] とうもろこし（直まき）
  - [ ] トマト（通常は苗を定植）
  - [ ] ナス（通常は苗を定植）
  - [x] ニンジン（直まき、重要）
  - [ ] 白菜（通常は苗を定植）
  - [ ] ピーマン（通常は苗を定植）
  - [ ] ブロッコリー（通常は苗を定植）
  - [x] ほうれん草（直まき）
  - [ ] レタス（通常は苗を定植）
  - [ ] 玉ねぎ（通常はセット球か苗を定植）

#### 14. `pruning` - 剪定
- **name**: `pruning`
- **description**: "不要な枝を切る作業"
- **time_per_sqm**: 0.02 時間/㎡
- **weather_dependency**: 'low'
- **required_tools**: `["剪定ばさみ"]` など
- **skill_level**: 'intermediate' または 'advanced'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（剪定が必要な果菜類）
  - [x] かぼちゃ（わき芽かき、摘芯）
  - [ ] キャベツ（通常不要）
  - [x] キュウリ（わき芽かき、摘芯）
  - [ ] ジャガイモ（通常不要）
  - [ ] 大根（通常不要）
  - [ ] とうもろこし（通常不要）
  - [x] トマト（わき芽かき、重要）
  - [x] ナス（わき芽かき）
  - [ ] ニンジン（通常不要）
  - [ ] 白菜（通常不要）
  - [x] ピーマン（わき芽かき、摘芯）
  - [ ] ブロッコリー（通常不要）
  - [ ] ほうれん草（通常不要）
  - [ ] レタス（通常不要）
  - [ ] 玉ねぎ（通常不要）

#### 15. `training` - 誘引
- **name**: `training`
- **description**: "作物を支柱などに誘引する作業"
- **time_per_sqm**: 0.015 時間/㎡
- **weather_dependency**: 'low'
- **required_tools**: `["結束バンド", "支柱"]` など
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（支柱に誘引が必要な作物）
  - [x] かぼちゃ（つるを誘引、支柱栽培の場合）
  - [ ] キャベツ（通常不要）
  - [x] キュウリ（つるを誘引、重要）
  - [ ] ジャガイモ（通常不要）
  - [ ] 大根（通常不要）
  - [ ] とうもろこし（通常不要）
  - [x] トマト（主枝を誘引、重要）
  - [x] ナス（主枝を誘引）
  - [ ] ニンジン（通常不要）
  - [ ] 白菜（通常不要）
  - [x] ピーマン（主枝を誘引）
  - [ ] ブロッコリー（通常不要）
  - [ ] ほうれん草（通常不要）
  - [ ] レタス（通常不要）
  - [ ] 玉ねぎ（通常不要）

#### 16. `grading` - 規格選別
- **name**: `grading`
- **description**: "収穫物を規格ごとに選別する作業"
- **time_per_sqm**: 0.05 時間/㎡（手作業の場合）
- **weather_dependency**: 'low'
- **required_tools**: `["選別用かご", "規格表", "はかり"]` など（重機は使用しない）
- **skill_level**: 'intermediate'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認（規格選別が必要な作物）
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

#### 17. `packaging` - 箱詰め・袋詰め
- **name**: `packaging`
- **description**: "出荷用の箱や袋に詰める作業"
- **time_per_sqm**: 0.03 時間/㎡
- **weather_dependency**: 'low'
- **required_tools**: `["箱", "袋", "ラベル"]` など
- **skill_level**: 'beginner'
- **is_reference**: true
- **region**: 'jp'（初期実装）
- **TODO**: 適用作物の割り当てを確認
  - [x] かぼちゃ
  - [x] キャベツ
  - [x] キュウリ
  - [x] ジャガイモ
  - [x] 大根
  - [x] とうもろこし
  - [x] トマト
  - [x] ナス
  - [x] ニンジン
  - [x] 白菜
  - [x] ピーマン
  - [x] ブロッコリー
  - [x] ほうれん草
  - [x] レタス
  - [x] 玉ねぎ

## マイグレーション作成時の注意点

1. **初期実装方針**: 
   - **まずは日本（region='jp'）のマスタデータのみを作成**
   - 全て参照タスク（is_reference=true）として作成
   - 後で他の地域（'us', 'in'など）を追加する際は別のマイグレーションで対応

2. **地域ごとの作成**: 各タスクは地域（'jp', 'us', 'in'）ごとに作成するか確認
   - 同じタスクでも地域によって名称や説明が異なる場合がある
   - 必要な場合は地域ごとに別レコードとして作成
   - 初期実装では'jp'のみを作成

3. **参照タスクの設定**: 
   - 全てのタスクは `is_reference=true` として作成
   - `user_id` は `null`（参照タスクはシステム所有）

4. **名前の一意性**: 
   - 参照タスク（is_reference=true）は名前で一意
   - 同じ名前のタスクを複数地域で作成する場合は、regionを含めた検索条件で確認
   - 初期実装（jpのみ）では、名前とis_reference=trueで一意性を確認

5. **必須属性**: 
   - `name` は必須
   - `region` は 'jp' を設定
   - `is_reference` は true を設定
   - `user_id` は null を設定
   - その他の属性はnullableだが、可能な限り設定することが推奨

6. **JSON配列の扱い**: 
   - `required_tools` はJSON配列として保存（例: `["ツール1", "ツール2"]`）
   - Rubyの配列を `to_json` でシリアライズして保存

7. **既存データの確認**: 
   - マイグレーション実行前に既存のagricultural_tasksテーブルに同じ名前のタスク（region='jp', is_reference=true）が存在しないか確認
   - 存在する場合は `find_or_initialize_by` を使用して更新するか、新しいレコードを作成するか検討

8. **工具について**: 
   - **重機は使用しない**前提で設定（トラクター、ロータリーティラー、大型機械などは含めない）
   - 手動工具のみを想定して`required_tools`を設定
   - `time_per_sqm`は手作業を前提とした所要時間を設定

9. **作業時間（time_per_sqm）について**: 
   - 単位は**時間/㎡**で保存
   - 手作業を前提とした現実的な値を設定
   - 実際の作業効率は作物の種類、作業者のスキル、天候などによって大きく変動するため、目安として設定
   - マイグレーション時に地域や文化によって異なる作業効率を考慮して調整することを推奨（初期実装では日本の標準的な値を設定）