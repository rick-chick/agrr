# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < ApplicationController
        skip_before_action :verify_authenticity_token, only: [:adjust]
        skip_before_action :authenticate_user!, only: [:adjust]
        
        # POST /api/v1/public_plans/cultivation_plans/:id/adjust
        # 既存の割り当てを手修正して再最適化
        def adjust
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          # 移動指示を受け取る
          moves = params[:moves] || []
          
          if moves.empty?
            return render json: {
              success: false,
              message: '移動指示がありません'
            }, status: :bad_request
          end
          
          # 現在の割り当てをAGRR形式に変換
          current_allocation = build_current_allocation(@cultivation_plan)
          
          # 圃場と作物の設定を構築
          fields = build_fields_config(@cultivation_plan)
          crops = build_crops_config(@cultivation_plan)
          
          # 気象データを取得
          farm = @cultivation_plan.farm
          unless farm.weather_location
            return render json: {
              success: false,
              message: '気象データがありません'
            }, status: :not_found
          end
          
          # 最適化時に保存した予測データを再利用
          if @cultivation_plan.predicted_weather_data.present?
            weather_data = @cultivation_plan.predicted_weather_data
            
            # 古い保存形式（ネスト構造）の場合は修正
            if weather_data['data'].is_a?(Hash) && weather_data['data']['data'].is_a?(Array)
              weather_data = weather_data['data']
            end
          else
            # フォールバック: その場で予測データを生成
            weather_data = get_weather_data_for_period(
              farm.weather_location,
              @cultivation_plan.planning_start_date,
              @cultivation_plan.planning_end_date,
              farm.latitude,
              farm.longitude
            )
          end
          
          # 交互作用ルールを構築
          interaction_rules = build_interaction_rules(@cultivation_plan)
          
          # agrr optimize adjust を実行
          begin
            adjust_gateway = Agrr::AdjustGateway.new
            result = adjust_gateway.adjust(
              current_allocation: current_allocation,
              moves: moves,
              fields: fields,
              crops: crops,
              weather_data: weather_data,
              planning_start: @cultivation_plan.planning_start_date,
              planning_end: @cultivation_plan.planning_end_date,
              interaction_rules: interaction_rules.empty? ? nil : { 'rules' => interaction_rules },
              objective: 'maximize_profit',
              enable_parallel: true
            )
            
            # 調整結果をデータベースに保存
            save_adjusted_result(@cultivation_plan, result)
            
            render json: {
              success: true,
              message: '調整が完了しました',
              cultivation_plan: {
                id: @cultivation_plan.id,
                total_profit: result[:total_profit],
                field_cultivations_count: @cultivation_plan.field_cultivations.count
              }
            }
          rescue Agrr::BaseGateway::ExecutionError => e
            Rails.logger.error "❌ [Adjust] Failed to adjust: #{e.message}"
            render json: {
              success: false,
              message: "調整に失敗しました: #{e.message}"
            }, status: :internal_server_error
          end
        end
        
        private
        
        # 現在の割り当てをAGRR形式に構築
        def build_current_allocation(cultivation_plan)
          field_schedules = []
          
          # 圃場ごとにグループ化
          cultivations_by_field = cultivation_plan.field_cultivations.group_by(&:cultivation_plan_field_id)
          
          cultivations_by_field.each do |field_id, cultivations|
            field = cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id }
            next unless field
            
            allocations = cultivations.map do |fc|
              {
                allocation_id: "alloc_#{fc.id}",
                crop_id: fc.cultivation_plan_crop.agrr_crop_id || fc.cultivation_plan_crop.name,
                crop_name: fc.crop_display_name,
                variety: fc.cultivation_plan_crop.name,
                area_used: fc.area,  # agrr optimize adjustが期待するフィールド
                start_date: fc.start_date.to_s,
                completion_date: fc.completion_date.to_s,
                growth_days: fc.cultivation_days,
                accumulated_gdd: fc.optimization_result&.dig('accumulated_gdd') || 0.0,
                total_cost: fc.estimated_cost || 0.0,
                expected_revenue: fc.optimization_result&.dig('revenue') || 0.0,
                profit: fc.optimization_result&.dig('profit') || 0.0
              }
            end
            
            field_schedules << {
              field_id: "field_#{field.id}",
              field_name: field.name,
              allocations: allocations
            }
          end
          
          {
            optimization_result: {
              optimization_id: "opt_#{cultivation_plan.id}",
              field_schedules: field_schedules,
              total_profit: cultivation_plan.field_cultivations.sum { |fc| fc.optimization_result&.dig('profit') || 0.0 }
            }
          }
        end
        
        # 圃場設定を構築
        def build_fields_config(cultivation_plan)
          cultivation_plan.cultivation_plan_fields.map do |field|
            {
              field_id: "field_#{field.id}",
              name: field.name,
              area: field.area,
              daily_fixed_cost: 0.0 # 公開計画では固定費なし
            }
          end
        end
        
        # 作物設定を構築
        def build_crops_config(cultivation_plan)
          cultivation_plan.cultivation_plan_crops.map do |plan_crop|
            # agrr_crop_idから参照作物を取得
            crop = if plan_crop.agrr_crop_id.present?
              Crop.find_by(id: plan_crop.agrr_crop_id) ||
                Crop.find_by(agrr_crop_id: plan_crop.agrr_crop_id) ||
                Crop.reference.find_by(name: plan_crop.name, variety: plan_crop.variety)
            else
              Crop.reference.find_by(name: plan_crop.name, variety: plan_crop.variety)
            end
            
            next unless crop
            
            # AGRR形式に変換
            crop.to_agrr_requirement['crop']
          end.compact
        end
        
        # 交互作用ルールを構築
        def build_interaction_rules(cultivation_plan)
          # 作物グループのマッピング
          crop_groups = {}
          cultivation_plan.cultivation_plan_crops.each do |plan_crop|
            crop = Crop.find_by(id: plan_crop.agrr_crop_id) ||
                   Crop.find_by(agrr_crop_id: plan_crop.agrr_crop_id) ||
                   Crop.reference.find_by(name: plan_crop.name, variety: plan_crop.variety)
            
            next unless crop
            
            crop_id = plan_crop.agrr_crop_id || plan_crop.name
            crop_groups[crop_id] = crop.groups || []
          end
          
          # 連作ペナルティルールを作成
          rules = []
          crop_groups.each do |crop_id, groups|
            groups.each do |group|
              rules << {
                rule_id: "continuous_#{group}_#{SecureRandom.hex(4)}",
                rule_type: 'continuous_cultivation',
                source_group: group,
                target_group: group,
                impact_ratio: 0.7,
                is_directional: true,
                description: "Continuous cultivation penalty for #{group}"
              }
            end
          end
          
          rules.uniq { |r| [r[:source_group], r[:target_group]] }
        end
        
        # 気象データを取得（FieldCultivationsControllerから移植）
        def get_weather_data_for_period(weather_location, start_date, end_date, latitude, longitude)
          # 過去20年分の訓練データを取得
          training_start_date = Date.current - 20.years
          training_end_date = Date.current - 2.days
          training_data = weather_location.weather_data
            .where(date: training_start_date..training_end_date)
            .order(:date)
          
          # 訓練データをAGRR形式に変換
          training_formatted = {
            'latitude' => latitude,
            'longitude' => longitude,
            'timezone' => weather_location.timezone || 'Asia/Tokyo',
            'data' => training_data.filter_map do |datum|
              next if datum.temperature_max.nil? || datum.temperature_min.nil?
              
              temp_mean = datum.temperature_mean || ((datum.temperature_max + datum.temperature_min) / 2.0)
              
              {
                'time' => datum.date.to_s,
                'temperature_2m_max' => datum.temperature_max,
                'temperature_2m_min' => datum.temperature_min,
                'temperature_2m_mean' => temp_mean,
                'precipitation_sum' => datum.precipitation || 0.0
              }
            end
          }
          
          # 予測が必要な日数を計算
          prediction_days = (end_date - Date.current).to_i + 1
          
          if prediction_days > 0
            # 予測データを生成
            prediction_gateway = Agrr::PredictionGateway.new
            future = prediction_gateway.predict(
              historical_data: training_formatted,
              days: prediction_days,
              model: 'lightgbm'
            )
            
            # 今年の実データを取得
            current_year_start = Date.new(Date.current.year, 1, 1)
            current_year_end = Date.current - 2.days
            current_year_data = weather_location.weather_data
              .where(date: current_year_start..current_year_end)
              .order(:date)
            
            current_year_formatted = {
              'latitude' => latitude,
              'longitude' => longitude,
              'timezone' => weather_location.timezone || 'Asia/Tokyo',
              'data' => current_year_data.filter_map do |datum|
                next if datum.temperature_max.nil? || datum.temperature_min.nil?
                
                temp_mean = datum.temperature_mean || ((datum.temperature_max + datum.temperature_min) / 2.0)
                
                {
                  'time' => datum.date.to_s,
                  'temperature_2m_max' => datum.temperature_max,
                  'temperature_2m_min' => datum.temperature_min,
                  'temperature_2m_mean' => temp_mean,
                  'precipitation_sum' => datum.precipitation || 0.0
                }
              end
            }
            
            # 実データと予測データをマージ
            merged_data = current_year_formatted['data'] + future['data']
            
            {
              'latitude' => latitude,
              'longitude' => longitude,
              'timezone' => weather_location.timezone || 'Asia/Tokyo',
              'data' => merged_data
            }
          else
            # 過去のデータのみ使用
            {
              'latitude' => latitude,
              'longitude' => longitude,
              'timezone' => weather_location.timezone || 'Asia/Tokyo',
              'data' => weather_location.weather_data
                .where(date: start_date..end_date)
                .order(:date)
                .filter_map do |datum|
                  next if datum.temperature_max.nil? || datum.temperature_min.nil?
                  
                  temp_mean = datum.temperature_mean || ((datum.temperature_max + datum.temperature_min) / 2.0)
                  
                  {
                    'time' => datum.date.to_s,
                    'temperature_2m_max' => datum.temperature_max,
                    'temperature_2m_min' => datum.temperature_min,
                    'temperature_2m_mean' => temp_mean,
                    'precipitation_sum' => datum.precipitation || 0.0
                  }
                end
            }
          end
        end
        
        # 調整結果をデータベースに保存
        def save_adjusted_result(cultivation_plan, result)
          # 既存の栽培スケジュールを削除
          cultivation_plan.field_cultivations.destroy_all
          
          # 新しい栽培スケジュールを作成
          result[:field_schedules].each do |field_schedule|
            # field_idから実際のCultivationPlanFieldを取得
            field_id_num = field_schedule['field_id'].gsub('field_', '').to_i
            plan_field = cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id_num }
            next unless plan_field
            
            field_schedule['allocations'].each do |allocation|
              # crop_idから実際のCultivationPlanCropを取得
              plan_crop = cultivation_plan.cultivation_plan_crops.find do |c|
                c.agrr_crop_id == allocation['crop_id'] || c.name == allocation['crop_id']
              end
              next unless plan_crop
              
              FieldCultivation.create!(
                cultivation_plan: cultivation_plan,
                cultivation_plan_field: plan_field,
                cultivation_plan_crop: plan_crop,
                start_date: Date.parse(allocation['start_date']),
                completion_date: Date.parse(allocation['completion_date']),
                cultivation_days: (Date.parse(allocation['completion_date']) - Date.parse(allocation['start_date'])).to_i + 1,
                area: allocation['area'],
                estimated_cost: allocation['cost'],
                optimization_result: allocation.slice('revenue', 'cost', 'profit', 'gdd', 'raw')
              )
            end
          end
          
          # 最適化結果を更新
          cultivation_plan.update!(
            optimization_result: result[:raw],
            status: 'completed'
          )
        end
      end
    end
  end
end

