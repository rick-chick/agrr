# frozen_string_literal: true

module Api
  module V1
    module Plans
      class FieldCultivationsController < ApplicationController
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token, only: [:update]
        
        def show
          @field_cultivation = find_field_cultivation
          
          render json: {
            id: @field_cultivation.id,
            field_name: @field_cultivation.field_display_name,
            crop_name: @field_cultivation.crop_display_name,
            area: @field_cultivation.area,
            start_date: @field_cultivation.start_date,
            completion_date: @field_cultivation.completion_date,
            cultivation_days: @field_cultivation.cultivation_days,
            estimated_cost: @field_cultivation.estimated_cost,
            gdd: @field_cultivation.optimization_result&.dig('raw', 'total_gdd'),
            status: @field_cultivation.status
          }
        end
        
        # GET /api/v1/plans/field_cultivations/:id/climate_data
        # 栽培期間の気温・GDDデータを返す（agrr progressコマンドを使用）
        def climate_data
          @field_cultivation = find_field_cultivation
          cultivation_plan = @field_cultivation.cultivation_plan
          farm = cultivation_plan.farm
          
          # plan_crop から作物を取得
          plan_crop = @field_cultivation.cultivation_plan_crop
          
          # ユーザーの作物から検索（is_reference: false）
          crop = if plan_crop&.agrr_crop_id.present?
            # まずIDで検索
            found_crop = current_user.crops.find_by(id: plan_crop.agrr_crop_id, is_reference: false)
            # IDで見つからない場合は、agrr_crop_idフィールドで検索
            found_crop ||= current_user.crops.find_by(agrr_crop_id: plan_crop.agrr_crop_id, is_reference: false)
            # それでも見つからない場合は、名前と品種で検索
            found_crop ||= current_user.crops.find_by(name: plan_crop.name, variety: plan_crop.variety, is_reference: false)
            found_crop
          else
            # agrr_crop_idがない場合は名前で検索
            current_user.crops.find_by(name: plan_crop.name, variety: plan_crop.variety, is_reference: false)
          end
          
          Rails.logger.info "🔍 [Plans Climate Data] plan_crop.agrr_crop_id: #{plan_crop&.agrr_crop_id}, found crop: #{crop&.id}"
          
          unless farm.weather_location
            return render json: { success: false, message: '気象データがありません' }, status: :not_found
          end
          
          # 栽培期間が設定されていない場合のエラーハンドリング
          unless @field_cultivation.start_date && @field_cultivation.completion_date
            return render json: { success: false, message: '栽培期間が設定されていません' }, status: :bad_request
          end
          
          # 作物が見つからない場合はエラー
          unless crop
            return render json: { success: false, message: '作物情報が見つかりません' }, status: :not_found
          end
          
          # 最適化時に保存した予測データを再利用
          if cultivation_plan.predicted_weather_data.present?
            Rails.logger.info "✅ [Plans Climate Data] Using saved predicted weather data from optimization"
            saved_data = cultivation_plan.predicted_weather_data
            
            # 古い保存形式（ネスト構造）の場合は修正
            if saved_data['data'].is_a?(Hash) && saved_data['data']['data'].is_a?(Array)
              Rails.logger.warn "⚠️ [Plans Climate Data] Old nested format detected, extracting inner data"
              weather_data_for_cli = saved_data['data']
            else
              weather_data_for_cli = saved_data
            end
          else
            Rails.logger.warn "⚠️ [Plans Climate Data] No saved weather data, generating on-the-fly"
            
            # 天気予報データを取得
            weather_service = WeatherForecastService.new(
              latitude: farm.latitude,
              longitude: farm.longitude,
              start_date: cultivation_plan.planning_start_date,
              end_date: cultivation_plan.planning_end_date
            )
            
            weather_data_for_cli = weather_service.generate_agrr_weather_data
            
            unless weather_data_for_cli['success']
              return render json: {
                success: false,
                message: '天気予報データの取得に失敗しました'
              }, status: :internal_server_error
            end
          end
          
          # 作物要件ファイルを作成
          crop_requirement = crop.to_agrr_requirement
          crop_requirement_path = Rails.root.join('tmp', "crop_req_#{SecureRandom.hex(8)}.json")
          File.write(crop_requirement_path, JSON.pretty_generate(crop_requirement))
          
          # 予測気象データを一時ファイルに保存
          predicted_weather_path = Rails.root.join('tmp', "predicted_weather_#{SecureRandom.hex(8)}.json")
          File.write(predicted_weather_path, JSON.pretty_generate(weather_data_for_cli))
          
          # agrr progress コマンドを実行
          start_date_str = @field_cultivation.start_date.strftime('%Y-%m-%d')
          
          result = AgrrCliService.run_progress(
            crop_requirement_file: crop_requirement_path.to_s,
            predicted_weather_file: predicted_weather_path.to_s,
            start_date: start_date_str
          )
          
          # 一時ファイルを削除
          File.delete(crop_requirement_path) if File.exist?(crop_requirement_path)
          File.delete(predicted_weather_path) if File.exist?(predicted_weather_path)
          
          if result[:success]
            # 気温データの変換（JSON文字列をオブジェクトに）
            progress_data = result[:data]
            
            # stage_progressをパース
            stages_data = progress_data['stage_progress'].map do |stage|
              {
                name: stage['stage_name'],
                start_date: stage['start_date'],
                completion_date: stage['completion_date'],
                days: stage['days'],
                gdd_accumulated: stage['gdd_accumulated'].round(1),
                gdd_required: stage['gdd_required'].round(1),
                completion_percentage: stage['completion_percentage'].round(1)
              }
            end
            
            # 日次データをパース
            daily_data = progress_data['daily_summary'].map do |day|
              {
                date: day['date'],
                temp_avg: day['temp_avg'].round(1),
                gdd: day['daily_gdd'].round(2),
                status: day['stress_level']
              }
            end
            
            render json: {
              success: true,
              data: {
                stages: stages_data,
                daily: daily_data,
                summary: {
                  total_gdd: progress_data['summary']['total_gdd_accumulated'].round(1),
                  completion_date: progress_data['summary']['estimated_completion_date'],
                  total_days: progress_data['summary']['total_cultivation_days']
                }
              }
            }
          else
            render json: {
              success: false,
              message: result[:error] || 'データの取得に失敗しました'
            }, status: :internal_server_error
          end
        rescue => e
          Rails.logger.error "❌ [Plans Climate Data] Error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        # PATCH /api/v1/plans/field_cultivations/:id
        def update
          @field_cultivation = find_field_cultivation
          
          if @field_cultivation.update(field_cultivation_params)
            render json: {
              success: true,
              field_cultivation: {
                id: @field_cultivation.id,
                start_date: @field_cultivation.start_date,
                completion_date: @field_cultivation.completion_date
              }
            }
          else
            render json: {
              success: false,
              errors: @field_cultivation.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
        
        private
        
        def find_field_cultivation
          field_cultivation = FieldCultivation.find(params[:id])
          cultivation_plan = field_cultivation.cultivation_plan
          
          # ユーザーの計画であることを確認
          unless cultivation_plan.plan_type_private? && cultivation_plan.user_id == current_user.id
            raise ActiveRecord::RecordNotFound
          end
          
          field_cultivation
        end
        
        def field_cultivation_params
          params.require(:field_cultivation).permit(:start_date, :completion_date)
        end
      end
    end
  end
end

