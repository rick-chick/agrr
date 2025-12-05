# 表示範囲設定ボタンの改善

## 現状の説明

現在の表示範囲設定UIは、以下の構成になっています：

1. **カレンダー入力エリア**（上部）
   - 開始日・終了日の日付入力フィールド
   - 適用ボタン
   - 縦幅を多く取る配置

2. **移動系ボタン群**（6ボタン）
   - ← 1年（year-back）
   - 1年 →（year-forward）
   - ← 1ヶ月（month-back）
   - 1ヶ月 →（month-forward）
   - ← 3ヶ月（quarter-back）
   - 3ヶ月 →（quarter-forward）

3. **ジャンプ系ボタン群**（3ボタン）
   - 計画開始日から（plan-start）
   - 計画終了日まで（plan-end）
   - 全体表示（full-range）

**問題点：**
- ボタンが多く、縦幅を多く取っている
- 移動系ボタンは現在の表示範囲を基準に相対的に移動するため、直感的でない
- 表示範囲の「幅」を直接選択できない

## 対応案の説明

### 改善方針

1. **不要なボタンの削除**
   - 「1年」ボタン（year-back、year-forward）を削除
   - 「3ヶ月のシフト」ボタン（quarter-back、quarter-forward）を削除
   - 「開始日から終了日まで」ボタン（plan-start、plan-end）を削除
   - 合計6ボタンを削除

2. **新ボタンの追加**
   - 「1年」ボタン：現在の開始日から1年間の範囲を設定
   - 「2年」ボタン：現在の開始日から2年間の範囲を設定
   - 「全体」ボタン：計画期間全体を表示（既存のfull-rangeを維持）

3. **レイアウトの最適化**
   - ボタンを横並びに配置し、縦幅を削減
   - カレンダー入力は控えめに配置（既存のスタイルを維持）
   - ボタン群を1行にまとめ、コンパクトに表示

### 実装詳細

#### ビューの変更
- `app/views/plans/show.html.erb`の表示範囲セクションを更新
- 削除するボタン：year-back、year-forward、quarter-back、quarter-forward、plan-start、plan-end
- 追加するボタン：range-1year、range-2year（full-rangeは既存）

#### JavaScriptの変更
- `app/assets/javascripts/custom_gantt_chart.js`の`handleQuickRangeAction`関数を更新
- 新アクション：`range-1year`、`range-2year`を実装
- 現在の開始日を基準に、1年または2年後の終了日を計算
- 計画期間を超えないように制約を追加

#### CSSの変更
- `app/assets/stylesheets/features/plans.css`を更新
- ボタン群を横並びに配置
- 縦幅を削減するスタイルを追加
- レスポンシブ対応を維持

#### 翻訳の変更
- `config/locales/views/plans.ja.yml`を更新
- 新ボタンのラベルを追加：`range_1year`、`range_2year`

#### テストの変更
- `test/system/plans_display_range_buttons_test.rb`を更新
- 削除されたボタンのテストを削除
- 新ボタンのテストを追加

## 実装TODO

1. ✅ 現状説明と対応案の文書作成
2. ⏳ ビューファイルの更新（ボタン削除と新ボタン追加）
3. ⏳ JavaScriptの更新（新ボタンの動作実装）
4. ⏳ CSSの更新（ボタン配置の最適化）
5. ⏳ 翻訳ファイルの更新
6. ⏳ テストファイルの更新

