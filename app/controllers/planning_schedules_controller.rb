# frozen_string_literal: true

class PlanningSchedulesController < ApplicationController
  before_action :authenticate_user!
  layout 'application'
  
  # デフォルト表示期間（来年から過去5年分）
  DEFAULT_YEARS_RANGE = 5
  
  # ほ場選択画面
  def fields_selection
    @farms = current_user.farms.user_owned.order(:name)
    @selected_farm_id = params[:farm_id]&.to_i || @farms.first&.id
    
    if @selected_farm_id
      @selected_farm = @farms.find_by(id: @selected_farm_id)
      if @selected_farm
        # 選択した農場のほ場を全計画から集約して取得
        @fields = collect_fields_from_plans(@selected_farm)
        requested_field_ids = Array(params[:field_ids]).filter_map do |field_id|
          value = field_id.to_s.strip
          next if value.blank?
          value.to_i
        end
        @selected_field_ids = requested_field_ids.presence || @fields.map { |f| f[:id] }
      else
        @fields = []
        @selected_field_ids = []
      end
    else
      @fields = []
      @selected_field_ids = []
    end
    
    # 表示期間（来年から過去5年分）
    current_year = Date.current.year
    next_year = current_year + 1
    @year_range = ((next_year - DEFAULT_YEARS_RANGE + 1)..next_year).to_a.reverse
  end
  
  # 作付け計画表画面
  def schedule
    # セッションまたはパラメータから選択情報を取得
    farm_id = params[:farm_id]&.to_i || session[:planning_schedule_farm_id]&.to_i
    field_ids = params[:field_ids]&.map(&:to_i) || session[:planning_schedule_field_ids]&.map(&:to_i) || []
    current_year = Date.current.year
    next_year = current_year + 1
    start_year = params[:year]&.to_i || (next_year - DEFAULT_YEARS_RANGE + 1)
    granularity = params[:granularity] || 'quarter'
    
    # バリデーション
    unless farm_id && field_ids.present?
      redirect_to fields_selection_planning_schedules_path, alert: I18n.t('planning_schedules.errors.select_fields')
      return
    end
    
    @farm = current_user.farms.user_owned.find_by(id: farm_id)
    unless @farm
      redirect_to fields_selection_planning_schedules_path, alert: I18n.t('planning_schedules.errors.farm_not_found')
      return
    end
    
    # セッションに保存
    session[:planning_schedule_farm_id] = farm_id
    session[:planning_schedule_field_ids] = field_ids
    
    # 選択されたほ場情報を取得
    all_fields = collect_fields_from_plans(@farm)
    @selected_fields = all_fields.select { |f| field_ids.include?(f[:id]) }
    
    # 表示年度の範囲（来年から過去5年分）
    @year_range = ((next_year - DEFAULT_YEARS_RANGE + 1)..next_year).to_a.reverse
    
    # 開始年度のバリデーション（来年から過去5年分の範囲内）
    unless @year_range.include?(start_year)
      start_year = next_year - DEFAULT_YEARS_RANGE + 1
    end
    @start_year = start_year
    @end_year = start_year + DEFAULT_YEARS_RANGE - 1  # 開始年度から5年分
    @years_range = DEFAULT_YEARS_RANGE
    
    # 表示粒度
    @granularity = granularity
    
    # 5年分の開始日と終了日
    period_start = Date.new(start_year, 1, 1)
    period_end = Date.new(@end_year, 12, 31)
    
    # 期間の行を生成（5年分、降順で表示）
    @periods = generate_periods(period_start, period_end, granularity).reverse
    # Presenter（ViewModel）
    @schedule_presenter = PlanningSchedulePresenter.new(periods: @periods)
    
    # 各ほ場の栽培情報を取得（5年分）
    @cultivations_by_field = {}
    @selected_fields.each do |field|
      field_id = field[:id]
      field_name = field[:name]
      
      # 5年分の計画から栽培情報を取得
      cultivations = get_cultivations_for_field(field_name, period_start, period_end)
      @cultivations_by_field[field_id] = cultivations
    end
  end
  
  # ヘルパーメソッドとして公開（ビューから呼び出し可能にするため）
  helper_method :get_crop_color_for_schedule
  
  # 作物名から一貫した色を取得（スケジュール表示用）
  def get_crop_color_for_schedule(crop_name)
    @crop_color_cache ||= {}
    
    return @crop_color_cache[crop_name] if @crop_color_cache[crop_name]
    
    # 色パレット（一般的な色の組み合わせ）
    color_palette = [
      { fill: 'rgba(154, 230, 180, 0.8)', stroke: '#48bb78', text: '#1a202c' },  # 緑1
      { fill: 'rgba(251, 211, 141, 0.8)', stroke: '#f6ad55', text: '#1a202c' },  # オレンジ
      { fill: 'rgba(144, 205, 244, 0.8)', stroke: '#4299e1', text: '#1a202c' },  # 青
      { fill: 'rgba(198, 246, 213, 0.8)', stroke: '#2f855a', text: '#1a202c' },  # 緑2
      { fill: 'rgba(254, 235, 200, 0.8)', stroke: '#dd6b20', text: '#1a202c' },  # 淡いオレンジ
      { fill: 'rgba(254, 178, 178, 0.8)', stroke: '#fc8181', text: '#1a202c' },  # 赤
      { fill: 'rgba(254, 243, 199, 0.8)', stroke: '#d69e2e', text: '#1a202c' },  # 黄色
      { fill: 'rgba(233, 213, 255, 0.8)', stroke: '#a78bfa', text: '#1a202c' },  # 紫
      { fill: 'rgba(191, 219, 254, 0.8)', stroke: '#60a5fa', text: '#1a202c' },  # 水色
      { fill: 'rgba(252, 231, 243, 0.8)', stroke: '#f472b6', text: '#1a202c' }   # ピンク
    ]
    
    # 作物名のハッシュから一貫したインデックスを生成
    color_index = crop_name.hash.abs % color_palette.size
    @crop_color_cache[crop_name] = color_palette[color_index]
    
    @crop_color_cache[crop_name]
  end
  
  private
  
  # 選択した農場のほ場を全計画から集約して取得
  def collect_fields_from_plans(farm)
    # ユーザーの全計画から、該当農場のほ場を集約
    plans = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .where(farm: farm)
      .includes(:cultivation_plan_fields)
    
    # ほ場名でグループ化（同じ名前のほ場は1つとして扱う）
    fields_hash = {}
    plans.each do |plan|
      plan.cultivation_plan_fields.each do |plan_field|
        field_name = plan_field.name
        unless fields_hash[field_name]
          fields_hash[field_name] = {
            id: field_name.hash.abs, # 名前のハッシュをIDとして使用
            name: field_name,
            area: plan_field.area,
            farm_name: farm.name
          }
        end
      end
    end
    
    fields_hash.values.sort_by { |f| f[:name] }
  end
  
  # 指定したほ場名と期間の栽培情報を取得
  def get_cultivations_for_field(field_name, start_date, end_date)
    # 表示期間と重複する計画を取得（作付計画の期間ベース）
    # 既存データ（plan_yearあり）と通年計画（plan_yearがnull）の両方に対応
    plans = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .where(farm: @farm)
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
    
    cultivations = []
    plans.each do |plan|
      # 計画の計算された期間が表示期間と重複するかチェック
      plan_start = plan.calculated_planning_start_date
      plan_end = plan.calculated_planning_end_date
      next unless plan_start && plan_end
      next unless plan_start <= end_date && plan_end >= start_date
      
      plan.field_cultivations.each do |field_cultivation|
        # ほ場名が一致し、期間が重なるものを取得
        if field_cultivation.cultivation_plan_field.name == field_name &&
           field_cultivation.start_date &&
           field_cultivation.completion_date &&
           field_cultivation.start_date <= end_date &&
           field_cultivation.completion_date >= start_date
          
          # 既存データ（plan_yearあり）の場合、重複防止のため開始年度がplan_yearと一致する場合のみ取得
          # 通年計画（plan_yearがnull）の場合は全て取得
          if plan.plan_year.nil? || field_cultivation.start_date.year == plan.plan_year
            cultivations << {
              crop_name: field_cultivation.cultivation_plan_crop.name,
              start_date: field_cultivation.start_date,
              completion_date: field_cultivation.completion_date,
              area: field_cultivation.area
            }
          end
        end
      end
    end
    
    cultivations.sort_by { |c| c[:start_date] }
  end
  
  # 期間の行を生成（月/四半期/半期）
  def generate_periods(start_date, end_date, granularity)
    periods = []
    
    case granularity
    when 'month'
      current = start_date
      while current <= end_date
        period_end = [current.end_of_month, end_date].min
        periods << {
          label: I18n.l(current, format: '%Y年%m月'),
          start_date: current,
          end_date: period_end
        }
        current = current.next_month.beginning_of_month
      end
    when 'quarter'
      current = start_date
      while current <= end_date
        quarter_num = ((current.month - 1) / 3) + 1
        quarter_end_month = quarter_num * 3
        quarter_end = [Date.new(current.year, quarter_end_month, -1), end_date].min
        periods << {
          label: "#{current.year} Q#{quarter_num}",
          start_date: current,
          end_date: quarter_end
        }
        # 次の四半期の開始日を計算
        if quarter_end_month == 12
          current = Date.new(current.year + 1, 1, 1)
        else
          current = Date.new(current.year, quarter_end_month + 1, 1)
        end
      end
    when 'half'
      current = start_date
      while current <= end_date
        half_end_month = current.month <= 6 ? 6 : 12
        half_end = [Date.new(current.year, half_end_month, -1), end_date].min
        periods << {
          label: "#{current.year} #{current.month <= 6 ? '上半期' : '下半期'}",
          start_date: current,
          end_date: half_end
        }
        if current.month <= 6
          current = Date.new(current.year, 7, 1)
        else
          current = Date.new(current.year + 1, 1, 1)
        end
      end
    end
    
    periods
  end
end

