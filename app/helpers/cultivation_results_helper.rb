# frozen_string_literal: true

module CultivationResultsHelper
  # 日付から開始日からの月インデックスを計算（1始まり）
  def calculate_month_index(date, plan_start)
    return nil unless date
    ((date.year - plan_start.year) * 12) + date.month - plan_start.month + 1
  end
  
  # plan_start_date と plan_end_date から総月数を計算
  def calculate_total_months(plan_start, plan_end)
    ((plan_end.year - plan_start.year) * 12) + plan_end.month - plan_start.month + 1
  end
  
  # 作物名からCSSクラス用の文字列を生成
  def crop_class(crop_name)
    crop_name.to_s.parameterize
  end
end

