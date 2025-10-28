# frozen_string_literal: true

# 栽培計画APIの共通機能を提供するConcern
#
# このConcernは以下の機能を提供します:
# - 作物の追加（add_crop）
# - 圃場の追加（add_field）
# - 圃場の削除（remove_field）
# - 計画データの取得（data）
# - 調整（adjust）
#
# 使い方:
# - find_api_cultivation_planメソッドを実装: 計画を検索する
# - get_crop_for_add_cropメソッドを実装: add_cropで使用する作物を取得する
module CultivationPlanApi
  extend ActiveSupport::Concern
  include AgrrOptimization
  
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_crop
  # 作物追加と手修正による調整
  def add_crop
    Rails.logger.info "🌱 [Add Crop] ========== START =========="
    Rails.logger.info "🌱 [Add Crop] cultivation_plan_id: #{params[:id]}, crop_id: #{params[:crop_id]}"
    
    @cultivation_plan = find_api_cultivation_plan
    
    # サブクラスで実装された作物取得メソッドを呼び出す
    crop = get_crop_for_add_crop(params[:crop_id])
    unless crop
      return render json: {
        success: false,
        message: i18n_t('errors.crop_not_found')
      }, status: :not_found
    end
    
    # cultivation_plan_crops に追加（スナップショット）
    # 作付け計画専用の作物を作成（スナップショット）
    plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
      crop: crop,  # 元のCropへの参照
      name: crop.name,
      variety: crop.variety,
      area_per_unit: crop.area_per_unit,
      revenue_per_area: crop.revenue_per_area
    )
    
    # 調整を実行
    moves = [
      {
        allocation_id: nil,
        action: 'add',
        crop_id: crop.id.to_s,  # Rails側のcrop.idを使用
        to_field_id: params[:field_id],
        to_start_date: params[:start_date],
        to_area: crop.area_per_unit,
        variety: crop.variety
      }
    ]
    
    # DBに保存された天気データを使って調整を実行
    result = adjust_with_db_weather(@cultivation_plan, moves)
    
    if result[:success]
      render json: {
        success: true,
        message: i18n_t('messages.crop_added'),
        crop: {
          id: plan_crop.id,
          name: plan_crop.display_name
        }
      }
    else
      render json: result, status: result[:status] || :internal_server_error
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ [Add Crop] Not found: #{e.message}"
    render json: { success: false, message: i18n_t('errors.not_found') }, status: :not_found
  rescue => e
    Rails.logger.error "❌ [Add Crop] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_field
  # 新しい圃場を追加
  def add_field
    @cultivation_plan = find_api_cultivation_plan
    
    # パラメータ取得
    field_name = params[:field_name]
    field_area = params[:field_area]&.to_f
    daily_fixed_cost = params[:daily_fixed_cost]&.to_f
    
    # バリデーション
    if field_area <= 0
      return render json: {
        success: false,
        message: i18n_t('errors.invalid_field_params')
      }, status: :unprocessable_entity
    end
    
    # 圃場数の制限（最大5個まで）
    if @cultivation_plan.cultivation_plan_fields.count >= 5
      return render json: {
        success: false,
        message: '圃場は最大5個までしか追加できません'
      }, status: :bad_request
    end
    
    # cultivation_plan_fields に追加
    plan_field = @cultivation_plan.cultivation_plan_fields.create!(
      name: field_name,
      area: field_area,
      daily_fixed_cost: daily_fixed_cost
    )
    
    # total_areaを更新
    @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
    
    # ActionCable経由で圃場追加を通知
    channel_class = @cultivation_plan.plan_type == 'private' ? PlansOptimizationChannel : OptimizationChannel
    channel_class.broadcast_to(
      @cultivation_plan,
      {
        type: 'field_added',
        field: {
          id: plan_field.id,
          field_id: plan_field.id,
          name: plan_field.name,
          area: plan_field.area
        },
        total_area: @cultivation_plan.total_area
      }
    )
    
    render json: {
      success: true,
      message: i18n_t('messages.field_added'),
      field: {
        id: plan_field.id,
        field_id: plan_field.id,
        name: plan_field.name,
        area: plan_field.area
      },
      total_area: @cultivation_plan.total_area
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      success: false,
      message: "圃場の追加に失敗しました: #{e.message}"
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "❌ [Add Field] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # DELETE /api/v1/{plans|public_plans}/cultivation_plans/:id/remove_field/:field_id
  # 圃場を削除
  def remove_field
    @cultivation_plan = find_api_cultivation_plan
    
    # field_idを整数に変換
    field_id = params[:field_id].to_i
    
    plan_field = @cultivation_plan.cultivation_plan_fields.find_by(id: field_id)
    
    unless plan_field
      return render json: {
        success: false,
        message: i18n_t('errors.field_not_found')
      }, status: :not_found
    end
    
    # 圃場に栽培がある場合は削除できない
    if plan_field.field_cultivations.any?
      return render json: {
        success: false,
        message: i18n_t('errors.cannot_remove_field_with_cultivations')
      }, status: :unprocessable_entity
    end
    
    # 最後の圃場は削除できない
    if @cultivation_plan.cultivation_plan_fields.count <= 1
      return render json: {
        success: false,
        message: i18n_t('errors.cannot_remove_last_field')
      }, status: :unprocessable_entity
    end
    
    # 圃場を削除
    plan_field.destroy!
    
    # total_areaを更新
    @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
    
    # ActionCable経由で圃場削除を通知
    channel_class = @cultivation_plan.plan_type == 'private' ? PlansOptimizationChannel : OptimizationChannel
    channel_class.broadcast_to(
      @cultivation_plan,
      {
        type: 'field_removed',
        field_id: field_id,
        total_area: @cultivation_plan.total_area
      }
    )
    
    render json: {
      success: true,
      message: i18n_t('messages.field_removed'),
      field_id: field_id,
      total_area: @cultivation_plan.total_area
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: i18n_t('errors.field_not_found') }, status: :not_found
  rescue => e
    Rails.logger.error "❌ [Remove Field] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # GET /api/v1/{plans|public_plans}/cultivation_plans/:id/data
  # 栽培計画データを取得
  def data
    @cultivation_plan = find_api_cultivation_plan
    
    # 計画データを構築
    fields_data = @cultivation_plan.cultivation_plan_fields.map do |field|
      {
        id: field.id,
        field_id: field.id,
        name: field.display_name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost
      }
    end
    
    crops_data = @cultivation_plan.cultivation_plan_crops.map do |crop|
      {
        id: crop.id,
        name: crop.display_name,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area
      }
    end
    
    cultivations_data = @cultivation_plan.field_cultivations.map do |fc|
      {
        id: fc.id,
        field_id: fc.cultivation_plan_field_id,
        field_name: fc.field_display_name,
        crop_id: fc.cultivation_plan_crop_id,
        crop_name: fc.crop_display_name,
        area: fc.area,
        start_date: fc.start_date,
        completion_date: fc.completion_date,
        cultivation_days: fc.cultivation_days,
        estimated_cost: fc.estimated_cost,
        revenue: fc.optimization_result&.dig('revenue') || 0.0,
        profit: fc.optimization_result&.dig('profit') || 0.0,
        status: fc.status
      }
    end
    
    render json: {
      success: true,
      data: {
        id: @cultivation_plan.id,
        plan_year: @cultivation_plan.plan_year,
        plan_name: @cultivation_plan.plan_name,
        status: @cultivation_plan.status,
        total_area: @cultivation_plan.total_area,
        planning_start_date: @cultivation_plan.planning_start_date,
        planning_end_date: @cultivation_plan.planning_end_date,
        fields: fields_data,
        crops: crops_data,
        cultivations: cultivations_data
      },
      total_profit: @cultivation_plan.total_profit,
      total_revenue: @cultivation_plan.total_revenue,
      total_cost: @cultivation_plan.total_cost
    }
  rescue => e
    Rails.logger.error "❌ [Data] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/adjust
  # 手修正後の再最適化
  # 
  # このメソッドはDBに保存された天気データを再利用し、
  # 不要な天気予測を実行しないことで高速化されています
  def adjust
    @cultivation_plan = find_api_cultivation_plan
    
    # 移動指示を受け取る
    moves_raw = params[:moves] || []
    
    Rails.logger.info "📥 [Adjust] Received moves: #{moves_raw.inspect}"
    Rails.logger.info "📥 [Adjust] Moves class: #{moves_raw.class}"
    
    # movesを適切な形式に変換
    moves = if moves_raw.is_a?(Array)
      moves_raw.map do |move|
        case move
        when ActionController::Parameters
          # permit!を使って全てのパラメータを許可してからハッシュに変換
          move.permit!.to_h.symbolize_keys
        when Hash
          move.symbolize_keys
        when String
          # JSONパース試行
          begin
            JSON.parse(move).symbolize_keys
          rescue JSON::ParserError
            Rails.logger.error "❌ [Adjust] Failed to parse move: #{move}"
            nil
          end
        else
          nil
        end
      end.compact
    else
      []
    end
    
    # 型変換を追加（AGRRとの互換性のため）
    moves = moves.map do |move|
      # allocation_idを数値に変換
      if move[:allocation_id].present?
        move[:allocation_id] = move[:allocation_id].to_i
      end
      
      # to_field_idを数値に変換
      if move[:to_field_id].present?
        move[:to_field_id] = move[:to_field_id].to_i
      end
      
      move
    end
    
    Rails.logger.info "🔧 [Adjust] Processed moves with type conversion: #{moves.inspect}"
    
    # DBに保存された天気データを使って調整を実行
    result = adjust_with_db_weather(@cultivation_plan, moves)
    
    render json: result, status: result[:status] || :ok
  rescue => e
    Rails.logger.error "❌ [Adjust] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  private
  
  # I18n翻訳のヘルパーメソッド
  def i18n_t(key)
    scope = @cultivation_plan&.plan_type == 'private' ? 'plans' : 'public_plans'
    I18n.t("#{scope}.#{key}")
  end
  
  # サブクラスで実装すべきメソッド
  
  # 計画を検索する
  def find_api_cultivation_plan
    raise NotImplementedError, "#{self.class}#find_api_cultivation_plan must be implemented"
  end
  
  # add_cropで使用する作物を取得する
  # @param crop_id [String, Integer] 作物ID
  # @return [Crop, nil] 作物オブジェクト
  def get_crop_for_add_crop(crop_id)
    raise NotImplementedError, "#{self.class}#get_crop_for_add_crop must be implemented"
  end
end

