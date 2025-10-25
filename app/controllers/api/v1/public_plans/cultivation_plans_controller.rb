# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < ApplicationController
        include CultivationPlanApi
        include AgrrOptimization
        
        skip_before_action :verify_authenticity_token, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        skip_before_action :authenticate_user!, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        
        # POST /api/v1/public_plans/cultivation_plans/:id/add_crop
        # 新しい作物をスケジュールに追加
        #
        # 【新規作物追加のフロー】
        # 1. CultivationPlanCropを作成または取得（作物マスタデータ）
        # 2. action: 'add'のmoveを作成
        #    - crop_id, to_field_id, to_start_date, to_areaを指定
        # 3. agrr optimize adjustを実行
        #    - current_allocationには既存の作物のみ
        #    - movesに新規作物追加を含める
        # 4. save_adjusted_resultで最適化結果をDBに保存
        #    - 既存のFieldCultivationを全削除
        #    - 最適化結果のみを新規作成
        def add_crop
          Rails.logger.info "🌱 [Add Crop] ========== START =========="
          Rails.logger.info "🌱 [Add Crop] cultivation_plan_id: #{params[:id]}, crop_id: #{params[:crop_id]}, field_id: #{params[:field_id]}, start_date: #{params[:start_date]}"
          
          begin
            @cultivation_plan = CultivationPlan
              .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
              .find(params[:id])
            
            Rails.logger.info "🌱 [Add Crop] 既存のfield_cultivations件数: #{@cultivation_plan.field_cultivations.count}"
            
            crop = Crop.find(params[:crop_id])
            field_id = params[:field_id]
            plan_field = @cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id }
            
            unless plan_field
              return render json: {
                success: false,
                message: '指定された圃場が見つかりません'
              }, status: :not_found
            end
          rescue ActiveRecord::RecordNotFound => e
            Rails.logger.error "❌ [Add Crop] Record not found: #{e.message}"
            return render json: {
              success: false,
              message: "データが見つかりません: #{e.message}"
            }, status: :not_found
          rescue => e
            Rails.logger.error "❌ [Add Crop] Unexpected error: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            return render json: {
              success: false,
              message: "予期しないエラーが発生しました: #{e.message}"
            }, status: :internal_server_error
          end
          
          # 同じ作物がすでにcultivation_plan_cropsに存在するか確認
          # crop_idで一致判定
          plan_crop = @cultivation_plan.cultivation_plan_crops.find do |pc|
            pc.crop_id == crop.id
          end
          
          # 存在しない場合は新規作成（作物種類の制限をチェック）
          unless plan_crop
            # 実際に使われている作物種類数をチェック（field_cultivationsに紐づいている作物）
            used_crop_count = @cultivation_plan.field_cultivations
              .joins(:cultivation_plan_crop)
              .select('DISTINCT cultivation_plan_crops.id')
              .count
            
            # 作物種類が5種類に達している場合はエラー
            if used_crop_count >= 5
              return render json: {
                success: false,
                message: '作物は最大5種類までしか追加できません'
              }, status: :bad_request
            end
            
            plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
              crop: crop,  # 元のCropへの参照
              name: crop.name,
              variety: crop.variety,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            )
          end
          
          start_date = Date.parse(params[:start_date])
          
          # 現在の割り当てを構築
          current_allocation = build_current_allocation(@cultivation_plan)
          
          # 新規作物追加のmoveを作成
          moves = [
            {
              allocation_id: nil,
              action: 'add',
              crop_id: crop.id.to_s,  # Rails側のcrop.idを使用
              to_field_id: field_id,
              to_start_date: start_date.to_s,
              to_area: crop.area_per_unit,
              variety: crop.variety
            }
          ]
          
          Rails.logger.info "🔧 [Add Crop] 新規作物追加のmoveを作成（action: 'add'）"
          Rails.logger.info "🔧 [Add Crop] crop_id: #{moves.first[:crop_id]}"
          Rails.logger.info "🔧 [Add Crop] move: #{moves.first.inspect}"
          
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
          
          unless @cultivation_plan.predicted_weather_data.present?
            return render json: {
              success: false,
              message: '気象予測データがありません。最適化を先に実行してください。'
            }, status: :not_found
          end
          
          weather_data = @cultivation_plan.predicted_weather_data
          
          # 古い保存形式の場合は修正
          if weather_data['data'].is_a?(Hash) && weather_data['data']['data'].is_a?(Array)
            weather_data = weather_data['data']
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
            
            # 結果を保存
            if result && result[:field_schedules].present?
              Rails.logger.info "💾 [Add Crop] 最適化結果を保存開始"
              save_adjusted_result(@cultivation_plan, result)
              
              # リロードして最新の状態を取得
              @cultivation_plan.reload
              Rails.logger.info "✅ [Add Crop] 保存完了: field_cultivations count = #{@cultivation_plan.field_cultivations.count}"
              
              # Action Cable経由でクライアントに通知
              broadcast_optimization_complete(@cultivation_plan)
              
              Rails.logger.info "🌱 [Add Crop] ========== SUCCESS =========="
              Rails.logger.info "🌱 [Add Crop] 最終的なfield_cultivations件数: #{@cultivation_plan.field_cultivations.count}"
              
              render json: {
                success: true,
                message: '作物を追加しました',
                cultivation_plan: {
                  id: @cultivation_plan.id,
                  total_profit: result[:total_profit],
                  field_cultivations_count: @cultivation_plan.field_cultivations.count
                }
              }
            else
              Rails.logger.error "❌ [Add Crop] Result has no field_schedules"
              render json: {
                success: false,
                message: "最適化結果が空です"
              }, status: :internal_server_error
            end
          rescue Agrr::BaseGateway::ExecutionError => e
            Rails.logger.error "❌ [Add Crop] ========== ERROR =========="
            Rails.logger.error "❌ [Add Crop] Failed to optimize: #{e.message}"
            
            # ユーザーフレンドリーなエラーメッセージに変換
            user_message = parse_optimization_error(e.message)
            
            render json: {
              success: false,
              message: user_message,
              technical_details: e.message # デバッグ用
            }, status: :internal_server_error
          rescue => e
            Rails.logger.error "❌ [Add Crop] Unexpected error in optimization: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            render json: {
              success: false,
              message: "最適化処理中にエラーが発生しました: #{e.message}"
            }, status: :internal_server_error
          end
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "❌ [Add Crop] Record not found: #{e.message}"
          render json: {
            success: false,
            message: "データが見つかりません: #{e.message}"
          }, status: :not_found
        rescue => e
          Rails.logger.error "❌ [Add Crop] Unexpected error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: {
            success: false,
            message: "予期しないエラーが発生しました: #{e.message}"
          }, status: :internal_server_error
        end
        
        # POST /api/v1/public_plans/cultivation_plans/:id/add_field
        # 新しい圃場を追加
        def add_field
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          field_name = params[:field_name]
          field_area = params[:field_area]&.to_f
          
          # バリデーション
          if field_area <= 0
            return render json: {
              success: false,
              message: '面積は0より大きい値を指定してください'
            }, status: :bad_request
          end
          
          # 圃場数の制限（最大5個まで）
          if @cultivation_plan.cultivation_plan_fields.count >= 5
            return render json: {
              success: false,
              message: '圃場は最大5個までしか追加できません'
            }, status: :bad_request
          end
          
          # 新しい圃場を作成
          new_field = @cultivation_plan.cultivation_plan_fields.create!(
            name: field_name,
            area: field_area,
            daily_fixed_cost: 0.0
          )
          
          Rails.logger.info "✅ [Add Field] 新しい圃場を作成: #{new_field.id} (#{new_field.name})"
          
          # 合計面積を更新
          @cultivation_plan.update!(
            total_area: @cultivation_plan.cultivation_plan_fields.sum(:area)
          )
          
          # ActionCable経由で圃場追加を通知
          ActionCable.server.broadcast(
            "optimization_#{@cultivation_plan.id}",
            {
              type: 'field_added',
              field: {
                id: new_field.id,
                field_id: new_field.id,
                name: new_field.name,
                area: new_field.area
              },
              total_area: @cultivation_plan.total_area
            }
          )
          
          render json: {
            success: true,
            message: '圃場を追加しました',
            field: {
              id: new_field.id,
              field_id: new_field.id,
              name: new_field.name,
              area: new_field.area
            }
          }
        rescue ActiveRecord::RecordInvalid => e
          render json: {
            success: false,
            message: "圃場の追加に失敗しました: #{e.message}"
          }, status: :bad_request
        rescue ActiveRecord::RecordNotFound => e
          render json: {
            success: false,
            message: "栽培計画が見つかりません"
          }, status: :not_found
        end
        
        # DELETE /api/v1/public_plans/cultivation_plans/:id/remove_field/:field_id
        # 圃場を削除
        def remove_field
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          field_id = params[:field_id]
          
          plan_field = @cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id }
          
          unless plan_field
            return render json: {
              success: false,
              message: '指定された圃場が見つかりません'
            }, status: :not_found
          end
          
          # 圃場に栽培がある場合は削除できない
          if plan_field.field_cultivations.any?
            return render json: {
              success: false,
              message: 'この圃場には栽培スケジュールが含まれています。先に作物を削除してください。'
            }, status: :bad_request
          end
          
          # 最後の圃場は削除できない
          if @cultivation_plan.cultivation_plan_fields.count <= 1
            return render json: {
              success: false,
              message: '最後の圃場は削除できません'
            }, status: :bad_request
          end
          
          Rails.logger.info "🗑️ [Remove Field] 圃場を削除: #{plan_field.id} (#{plan_field.name})"
          
          plan_field.destroy!
          
          # 合計面積を更新
          @cultivation_plan.update!(
            total_area: @cultivation_plan.cultivation_plan_fields.sum(:area)
          )
          
          # 再最適化を実行（栽培スケジュールの再調整）
          OptimizeCultivationPlanJob.perform_later(@cultivation_plan.id)
          
          render json: {
            success: true,
            message: '圃場を削除しました',
            field_id: field_id_str
          }
        rescue ActiveRecord::RecordNotFound => e
          render json: {
            success: false,
            message: "栽培計画が見つかりません"
          }, status: :not_found
        end
        
        # GET /api/v1/public_plans/cultivation_plans/:id/data
        # 栽培計画データを取得
        def data
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop], cultivation_plan_fields: [])
            .find(params[:id])
          
        # 栽培データを構築
        cultivations = @cultivation_plan.field_cultivations.map do |fc|
          {
            id: fc.id,
            crop_name: fc.crop_display_name,
            field_name: fc.cultivation_plan_field.name,
            field_id: fc.cultivation_plan_field_id,
            start_date: fc.start_date.to_s,
            completion_date: fc.completion_date.to_s,
            cultivation_days: fc.cultivation_days,
            area: fc.area,
            estimated_cost: fc.estimated_cost,
            profit: fc.optimization_result&.dig('profit') || 0.0,
            revenue: fc.optimization_result&.dig('revenue') || 0.0
          }
        end
        
        # 圃場情報を構築
        fields = @cultivation_plan.cultivation_plan_fields.map do |field|
          {
            id: field.id,
            field_id: field.id,
            name: field.name,
            area: field.area
          }
        end
          
          # 新スキーマ（Concern版に合わせる）
          payload = {
            success: true,
            data: {
              id: @cultivation_plan.id,
              plan_year: @cultivation_plan.plan_year,
              plan_name: @cultivation_plan.plan_name,
              status: @cultivation_plan.status,
              total_area: @cultivation_plan.total_area,
              planning_start_date: @cultivation_plan.planning_start_date,
              planning_end_date: @cultivation_plan.planning_end_date,
              fields: fields,
              cultivations: cultivations
            },
            totals: {
              profit: @cultivation_plan.total_profit,
              revenue: @cultivation_plan.total_revenue,
              cost: @cultivation_plan.total_cost
            }
          }

          # 互換性維持のため、従来のトップレベルキーも同梱（将来削除予定）
          payload.merge!({
            cultivations: cultivations,
            fields: fields,
            total_profit: @cultivation_plan.total_profit,
            total_revenue: @cultivation_plan.total_revenue,
            total_cost: @cultivation_plan.total_cost
          })

          render json: payload
        rescue ActiveRecord::RecordNotFound
          render json: {
            success: false,
            message: '栽培計画が見つかりません'
          }, status: :not_found
        end
        
        # adjust メソッドは CultivationPlanApi concern で実装されています
        # DBに保存された天気データを再利用し、不要な天気予測を実行しません
        
        private
        
        # Concernで実装すべきメソッド
        
        def find_api_cultivation_plan
          CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
        end
        
        def get_crop_for_add_crop(crop_id)
          Crop.find(crop_id)
        end
        
        # 公開版特有のメソッド（Concernに移動済みのメソッドを使用）
        # - parse_optimization_error: AgrrOptimizationに移動済み
        # - broadcast_optimization_complete: AgrrOptimizationに移動済み
        # - build_current_allocation: AgrrOptimizationに移動済み
        # - build_fields_config: AgrrOptimizationに移動済み
        # - build_crops_config: AgrrOptimizationに移動済み
        # - build_interaction_rules: AgrrOptimizationに移動済み
        # - save_adjusted_result: AgrrOptimizationに移動済み
        
        # 作物の栽培期間を推定（GDD要件から）
        def estimate_cultivation_days(crop, cultivation_plan)
          # 作物のGDD要件を取得
          begin
            crop_requirement = crop.to_agrr_requirement
            stage_requirements = crop_requirement['stage_requirements'] || []
            
            # 全ステージのGDDを合計
            total_gdd_required = stage_requirements.sum { |stage| stage['thermal']['required_gdd'] }
            
            # 基準温度を取得
            base_temp = stage_requirements.first&.dig('temperature', 'base_temperature') || 10.0
            
            # 気象データから平均日別GDDを計算
            weather_data = cultivation_plan.predicted_weather_data
            if weather_data && weather_data['data'].is_a?(Array) && weather_data['data'].any?
              daily_temps = weather_data['data'].map do |datum|
                (datum['temperature_2m_max'].to_f + datum['temperature_2m_min'].to_f) / 2.0
              end
              
              avg_daily_temp = daily_temps.sum / daily_temps.size
              avg_daily_gdd = [avg_daily_temp - base_temp, 0].max
              
              # 必要な日数を計算
              if avg_daily_gdd > 0
                estimated_days = (total_gdd_required / avg_daily_gdd).ceil
                return [estimated_days, 30].max # 最低30日
              end
            end
          rescue => e
            Rails.logger.warn "⚠️ [Estimate Days] Failed to estimate: #{e.message}"
          end
          
          # フォールバック: デフォルト値
          90
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
                'temperature_2m_max' => datum.temperature_max.to_f,
                'temperature_2m_min' => datum.temperature_min.to_f,
                'temperature_2m_mean' => temp_mean.to_f,
                'precipitation_sum' => (datum.precipitation || 0.0).to_f
              }
            end
          }
          
          # 予測が必要な日数を計算
          # AGRRは訓練データの最終日（training_end_date）の翌日から予測を開始するため、
          # training_end_dateからend_dateまでの日数を計算
          prediction_days = (end_date - training_end_date).to_i
          
          if prediction_days > 0
            # 予測データを生成
            prediction_gateway = Agrr::PredictionGateway.new
            future = prediction_gateway.predict(
              historical_data: training_formatted,
              days: prediction_days,
              model: 'lightgbm'
            )
            
            # 今年の実データを取得（training_end_dateまで）
            current_year_start = Date.new(Date.current.year, 1, 1)
            current_year_end = training_end_date
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
      end
    end
  end
end

