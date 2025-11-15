# frozen_string_literal: true

class PlanningSchedulesController < ApplicationController
  before_action :authenticate_user!
  layout 'application'
  
  # デフォルト表示期間（今年から5年分）
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
        @selected_field_ids = params[:field_ids]&.map(&:to_i) || @fields.map { |f| f[:id] }
      else
        @fields = []
        @selected_field_ids = []
      end
    else
      @fields = []
      @selected_field_ids = []
    end
    
    # 表示期間（今年から5年分）
    current_year = Date.current.year
    @year_range = (current_year..(current_year + DEFAULT_YEARS_RANGE - 1)).to_a
  end
  
  # 作付け計画表画面
  def schedule
    # セッションまたはパラメータから選択情報を取得
    farm_id = params[:farm_id]&.to_i || session[:planning_schedule_farm_id]&.to_i
    field_ids = params[:field_ids]&.map(&:to_i) || session[:planning_schedule_field_ids]&.map(&:to_i) || []
    start_year = params[:year]&.to_i || Date.current.year
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
    
    # 表示年度の範囲（今年から5年分）
    current_year = Date.current.year
    @year_range = (current_year..(current_year + DEFAULT_YEARS_RANGE - 1)).to_a
    
    # 開始年度のバリデーション（今年から5年分の範囲内）
    unless @year_range.include?(start_year)
      start_year = current_year
    end
    @start_year = start_year
    @end_year = start_year + DEFAULT_YEARS_RANGE - 1
    @years_range = DEFAULT_YEARS_RANGE
    
    # 表示粒度
    @granularity = granularity
    
    # 5年分の開始日と終了日
    period_start = Date.new(start_year, 1, 1)
    period_end = Date.new(@end_year, 12, 31)
    
    # 期間の行を生成（5年分）
    @periods = generate_periods(period_start, period_end, granularity)
    
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
    # ユーザーの全計画から、該当ほ場名と期間の栽培情報を取得
    plans = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .where(farm: @farm)
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
    
    cultivations = []
    plans.each do |plan|
      plan.field_cultivations.each do |field_cultivation|
        # ほ場名が一致し、期間が重なるものを取得
        if field_cultivation.cultivation_plan_field.name == field_name &&
           field_cultivation.start_date &&
           field_cultivation.completion_date &&
           field_cultivation.start_date <= end_date &&
           field_cultivation.completion_date >= start_date
          
          cultivations << {
            crop_name: field_cultivation.cultivation_plan_crop.name,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            area: field_cultivation.area
          }
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

