# 計画スケジュール表のリファクタリング余地調査

## 調査日
2024年（現在）

## 調査対象
- `app/views/planning_schedules/schedule.html.erb`
- `app/services/schedule_table_field_arranger.rb`
- `app/helpers/planning_schedules_helper.rb`

## 発見された改善点

### 1. ビューコードの重複（優先度: 高）

#### 1.1 作付セル描画の重複
**問題**: 作付セルのHTML生成が3箇所で重複している
- `colspan=2`の場合（144-154行目）
- `slot_0`の場合（180-190行目）
- `slot_1`の場合（210-220行目）

**重複コード**:
```erb
<td class="schedule-table-cell" colspan="<%= colspan %>" style="vertical-align: top;" <%= raw rowspan_attr_string(rowspan) %>>
  <div class="cultivation-items">
    <div class="cultivation-item" style="background-color: <%= crop_color[:fill] %>; border-left: 4px solid <%= crop_color[:stroke] %>; color: <%= crop_color[:text] %>;">
      <div class="cultivation-crop-name"><%= cultivation[:crop_name] %></div>
      <div class="cultivation-period">
        <%= I18n.l(cultivation[:start_date], format: :short) %> - 
        <%= I18n.l(cultivation[:completion_date], format: :short) %>
      </div>
    </div>
  </div>
</td>
```

**提案**: ヘルパーメソッド `render_cultivation_cell` を作成
```ruby
def render_cultivation_cell(cultivation_info:, colspan:, period_index:)
  return '' unless cultivation_starts_in_period?(cultivation_info, period_index)
  
  cultivation = cultivation_info[:cultivation]
  crop_color = get_crop_color_for_schedule(cultivation[:crop_name])
  # ... HTML生成
end
```

**影響**: 動作変更なし、可読性向上

#### 1.2 空白セル描画の重複
**問題**: 空白セルのHTML生成が複数箇所で重複している
- 129-133行目（`colspan=2`）
- 162-166行目（`colspan=2`）
- 197-200行目（`colspan=1`）
- 227-230行目（`colspan=1`）

**重複コード**:
```erb
<td class="schedule-table-cell" colspan="<%= colspan %>">
  <div class="cultivation-empty">
    <%= t('planning_schedules.schedule.no_cultivation') if show_label %>
  </div>
</td>
```

**提案**: ヘルパーメソッド `render_empty_cell` を作成
```ruby
def render_empty_cell(colspan:, show_label: true)
  # ... HTML生成
end
```

**影響**: 動作変更なし、可読性向上

### 2. 変数名の統一（優先度: 低）

#### 2.1 変数名の混在
**問題**: `cultivation_item`と`cultivation_info`が混在している
- `cultivation_info`: 配置情報を含むハッシュ（`start_period_index`, `rowspan`, `slot_index`など）
- `cultivation_item`: `cultivation_info[:cultivation]`から取得した作付データ

**現状**: 使い分けは明確だが、命名が一貫していない

**提案**: 現状維持（動作を変えない範囲での変更は困難）

### 3. サービスオブジェクトの改善（優先度: 中）

#### 3.1 `arrange`メソッドの長さ
**問題**: `arrange`メソッドが142行と長い

**現状**: ステップごとにコメントで分割されている
- ステップ1: 期間の決定（33-59行目）
- ステップ2: 作付の配置（61-87行目）
- ステップ3: 保留作付の処理（89-104行目）
- ステップ4: colspanの決定（109-139行目）

**提案**: 消極的なリファクタリングとしては現状維持
- 各ステップは論理的に分離されている
- メソッド分割は動作に影響する可能性がある

### 4. ヘルパーメソッドの重複（優先度: 低）

#### 4.1 `calculate_period_colspan`と`ScheduleTableFieldArranger`のロジック
**問題**: 期間のcolspanを計算するロジックが2箇所にある
- `PlanningSchedulesHelper#calculate_period_colspan`（ビュー用）
- `ScheduleTableFieldArranger#arrange`内（サービス用）

**現状**: 完全に同じではないが、似たロジック

**提案**: 現状維持
- ビューとサービスの責務が異なる
- 統合すると依存関係が複雑になる

### 5. コメントの整理（優先度: 低）

#### 5.1 冗長なコメント
**問題**: 一部のコメントが冗長
- 156-158行目: 継続中のセルに関する説明が3行
- 192-193行目: 同様の説明が2行

**提案**: 簡潔にまとめる（動作に影響なし）

## 推奨されるリファクタリング順序

1. **優先度: 高** - 作付セル描画のヘルパーメソッド化
2. **優先度: 高** - 空白セル描画のヘルパーメソッド化
3. **優先度: 低** - コメントの整理

## 注意事項

- すべてのリファクタリングは動作を変えない範囲で実施
- テストを通過することを確認
- 段階的に実施し、各ステップでテストを実行

