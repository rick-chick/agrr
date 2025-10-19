# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < ApplicationController
        skip_before_action :verify_authenticity_token, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        skip_before_action :authenticate_user!, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        
        # POST /api/v1/public_plans/cultivation_plans/:id/add_crop
        # 新しい作物をスケジュールに追加
        def add_crop
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          crop = Crop.find(params[:crop_id])
          field_id_str = params[:field_id] # "field_123" 形式
          field_id_num = field_id_str.gsub('field_', '').to_i
          plan_field = @cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id_num }
          
          unless plan_field
            return render json: {
              success: false,
              message: '指定された圃場が見つかりません'
            }, status: :not_found
          end
          
          # 同じ作物がすでにcultivation_plan_cropsに存在するか確認
          plan_crop = @cultivation_plan.cultivation_plan_crops.find do |pc|
            pc.agrr_crop_id == crop.id || pc.agrr_crop_id == crop.agrr_crop_id || pc.name == crop.name
          end
          
          # 存在しない場合は新規作成
          unless plan_crop
            plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
              name: crop.name,
              variety: crop.variety,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area,
              agrr_crop_id: crop.id
            )
          end
          
          # 移動として追加（adjust APIを使用）
          start_date = Date.parse(params[:start_date])
          
          # 新しい割り当てIDを生成（既存と重複しないように）
          max_id = @cultivation_plan.field_cultivations.maximum(:id) || 0
          new_allocation_id = "alloc_new_#{max_id + 1}_#{Time.current.to_i}"
          
          # 作物の栽培期間を推定（GDD要件から）
          estimated_days = estimate_cultivation_days(crop, @cultivation_plan)
          completion_date = start_date + estimated_days.days
          
          # 一時的なfield_cultivationを作成（adjust API用のcurrent_allocationに含める）
          temp_cultivation = @cultivation_plan.field_cultivations.create!(
            cultivation_plan_field: plan_field,
            cultivation_plan_crop: plan_crop,
            start_date: start_date,
            completion_date: completion_date,
            cultivation_days: estimated_days,
            area: crop.area_per_unit || 1.0,
            estimated_cost: 0,
            status: 'pending'
          )
          
          Rails.logger.info "✅ [Add Crop] 一時的なfield_cultivation作成: #{temp_cultivation.id}"
          
          # cultivation_planをリロードして新しいfield_cultivationを含める
          @cultivation_plan.reload
          
          # 現在の割り当てをAGRR形式に構築（新しく作成したtemp_cultivationも含める）
          current_allocation = build_current_allocation(@cultivation_plan)
          
          # movesは空（新しい作物はcurrent_allocationに含まれているので移動不要）
          moves = []
          
          Rails.logger.info "🔧 [Add Crop] 新しい作物をcurrent_allocationに含めました（moves不要）"
          Rails.logger.info "🔧 [Add Crop] field_cultivations count: #{@cultivation_plan.field_cultivations.count}"
          Rails.logger.info "🔧 [Add Crop] current_allocation field_schedules: #{current_allocation.dig(:optimization_result, :field_schedules)&.count}"
          
          # 圃場と作物の設定を構築
          fields = build_fields_config(@cultivation_plan)
          crops = build_crops_config(@cultivation_plan)
          
          # 気象データを取得
          farm = @cultivation_plan.farm
          unless farm.weather_location
            temp_cultivation.destroy
            return render json: {
              success: false,
              message: '気象データがありません'
            }, status: :not_found
          end
          
          unless @cultivation_plan.predicted_weather_data.present?
            temp_cultivation.destroy
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
              temp_cultivation.destroy
              Rails.logger.error "❌ [Add Crop] Result has no field_schedules"
              render json: {
                success: false,
                message: "最適化結果が空です"
              }, status: :internal_server_error
            end
          rescue Agrr::BaseGateway::ExecutionError => e
            temp_cultivation.destroy
            Rails.logger.error "❌ [Add Crop] Failed to optimize: #{e.message}"
            
            # ユーザーフレンドリーなエラーメッセージに変換
            user_message = parse_optimization_error(e.message)
            
            render json: {
              success: false,
              message: user_message,
              technical_details: e.message # デバッグ用
            }, status: :internal_server_error
          end
        rescue ActiveRecord::RecordNotFound => e
          render json: {
            success: false,
            message: "データが見つかりません: #{e.message}"
          }, status: :not_found
        end
        
        # POST /api/v1/public_plans/cultivation_plans/:id/add_field
        # 新しい圃場を追加
        def add_field
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          field_name = params[:field_name] || "圃場#{@cultivation_plan.cultivation_plan_fields.count + 1}"
          field_area = params[:field_area]&.to_f || 100.0
          
          # バリデーション
          if field_area <= 0
            return render json: {
              success: false,
              message: '面積は0より大きい値を指定してください'
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
          
          render json: {
            success: true,
            message: '圃場を追加しました',
            field: {
              id: new_field.id,
              field_id: "field_#{new_field.id}",
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
          
          field_id_str = params[:field_id] # "field_123" 形式
          field_id_num = field_id_str.gsub('field_', '').to_i
          
          plan_field = @cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id_num }
          
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
            field_id: "field_#{fc.cultivation_plan_field_id}",
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
            field_id: "field_#{field.id}",
            name: field.name,
            area: field.area
          }
        end
          
          render json: {
            success: true,
            cultivations: cultivations,
            fields: fields,
            total_profit: @cultivation_plan.total_profit,
            total_revenue: @cultivation_plan.total_revenue,
            total_cost: @cultivation_plan.total_cost
          }
        rescue ActiveRecord::RecordNotFound
          render json: {
            success: false,
            message: '栽培計画が見つかりません'
          }, status: :not_found
        end
        
        # POST /api/v1/public_plans/cultivation_plans/:id/adjust
        # 既存の割り当てを手修正して再最適化
        def adjust
          perf_start = Time.current
          Rails.logger.info "⏱️ [PERF] adjust() 開始: #{perf_start}"
          
          @cultivation_plan = CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(params[:id])
          
          perf_db_load = Time.current
          Rails.logger.info "⏱️ [PERF] DB読み込み完了: #{((perf_db_load - perf_start) * 1000).round(2)}ms"
          
          # 移動指示を受け取る
          moves_raw = params[:moves] || []
          
          Rails.logger.info "📥 [Adjust] Received moves: #{moves_raw.inspect}"
          Rails.logger.info "📥 [Adjust] Moves class: #{moves_raw.class}"
          Rails.logger.info "📥 [Adjust] First move class: #{moves_raw.first&.class}"
          
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
          
          if moves.empty?
            return render json: {
              success: false,
              message: '移動指示がありません'
            }, status: :bad_request
          end
          
          # 現在の割り当てをAGRR形式に変換
          perf_before_allocation = Time.current
          current_allocation = build_current_allocation(@cultivation_plan)
          perf_after_allocation = Time.current
          Rails.logger.info "⏱️ [PERF] 割り当てデータ構築: #{((perf_after_allocation - perf_before_allocation) * 1000).round(2)}ms"
          
          # 圃場と作物の設定を構築
          fields = build_fields_config(@cultivation_plan)
          perf_after_fields = Time.current
          Rails.logger.info "⏱️ [PERF] 圃場設定構築: #{((perf_after_fields - perf_after_allocation) * 1000).round(2)}ms"
          
          crops = build_crops_config(@cultivation_plan)
          perf_after_crops = Time.current
          Rails.logger.info "⏱️ [PERF] 作物設定構築: #{((perf_after_crops - perf_after_fields) * 1000).round(2)}ms"
          
          # デバッグ用にファイルを保存（本番環境以外のみ）
          unless Rails.env.production?
            debug_dir = Rails.root.join('tmp/debug')
            FileUtils.mkdir_p(debug_dir)
            debug_current_allocation_path = debug_dir.join("adjust_current_allocation_#{Time.current.to_i}.json")
            debug_moves_path = debug_dir.join("adjust_moves_#{Time.current.to_i}.json")
            debug_fields_path = debug_dir.join("adjust_fields_#{Time.current.to_i}.json")
            debug_crops_path = debug_dir.join("adjust_crops_#{Time.current.to_i}.json")
            File.write(debug_current_allocation_path, JSON.pretty_generate(current_allocation))
            File.write(debug_moves_path, JSON.pretty_generate({ 'moves' => moves }))
            File.write(debug_fields_path, JSON.pretty_generate({ 'fields' => fields }))
            File.write(debug_crops_path, JSON.pretty_generate({ 'crops' => crops }))
            Rails.logger.info "📁 [Adjust Controller] Debug current_allocation saved to: #{debug_current_allocation_path}"
            Rails.logger.info "📁 [Adjust Controller] Debug moves saved to: #{debug_moves_path}"
            Rails.logger.info "📁 [Adjust Controller] Debug fields saved to: #{debug_fields_path}"
            Rails.logger.info "📁 [Adjust Controller] Debug crops saved to: #{debug_crops_path}"
          end
          
          # 気象データを取得
          farm = @cultivation_plan.farm
          unless farm.weather_location
            return render json: {
              success: false,
              message: '気象データがありません'
            }, status: :not_found
          end
          
          # 最適化時に保存した予測データを再利用
          unless @cultivation_plan.predicted_weather_data.present?
            return render json: {
              success: false,
              message: '気象予測データがありません。最適化を先に実行してください。'
            }, status: :not_found
          end
          
          weather_data = @cultivation_plan.predicted_weather_data
          
          # 古い保存形式（ネスト構造）の場合は修正
          if weather_data['data'].is_a?(Hash) && weather_data['data']['data'].is_a?(Array)
            weather_data = weather_data['data']
          end
          
          # 交互作用ルールを構築
          perf_before_rules = Time.current
          interaction_rules = build_interaction_rules(@cultivation_plan)
          perf_after_rules = Time.current
          Rails.logger.info "⏱️ [PERF] 交互作用ルール構築: #{((perf_after_rules - perf_before_rules) * 1000).round(2)}ms"
          
          # agrr optimize adjust を実行
          begin
            perf_before_adjust = Time.current
            Rails.logger.info "⏱️ [PERF] AdjustGateway.adjust() 呼び出し開始"
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
            
            perf_after_adjust = Time.current
            Rails.logger.info "⏱️ [PERF] AdjustGateway.adjust() 完了: #{((perf_after_adjust - perf_before_adjust) * 1000).round(2)}ms"
            
            # 結果が正常に取得できた場合のみデータベースに保存
            if result && result[:field_schedules].present?
              perf_before_save = Time.current
              save_adjusted_result(@cultivation_plan, result)
              perf_after_save = Time.current
              Rails.logger.info "⏱️ [PERF] DB保存完了: #{((perf_after_save - perf_before_save) * 1000).round(2)}ms"
              
              perf_end = Time.current
              Rails.logger.info "⏱️ [PERF] === 合計処理時間 ==="
              Rails.logger.info "⏱️ [PERF] 全体: #{((perf_end - perf_start) * 1000).round(2)}ms"
              Rails.logger.info "⏱️ [PERF] - DB読み込み: #{((perf_db_load - perf_start) * 1000).round(2)}ms"
              Rails.logger.info "⏱️ [PERF] - データ構築: #{((perf_before_adjust - perf_db_load) * 1000).round(2)}ms"
              Rails.logger.info "⏱️ [PERF] - agrr adjust実行: #{((perf_after_adjust - perf_before_adjust) * 1000).round(2)}ms"
              Rails.logger.info "⏱️ [PERF] - DB保存: #{((perf_after_save - perf_before_save) * 1000).round(2)}ms"
              
              # Action Cable経由でクライアントに通知
              broadcast_optimization_complete(@cultivation_plan)
              
              render json: {
                success: true,
                message: '調整が完了しました',
                cultivation_plan: {
                  id: @cultivation_plan.id,
                  total_profit: result[:total_profit],
                  field_cultivations_count: @cultivation_plan.field_cultivations.count
                }
              }
            else
              Rails.logger.error "❌ [Adjust] Result has no field_schedules"
              render json: {
                success: false,
                message: "調整結果が空です"
              }, status: :internal_server_error
            end
          rescue Agrr::BaseGateway::ExecutionError => e
            Rails.logger.error "❌ [Adjust] Failed to adjust: #{e.message}"
            # エラー時はデータを削除しない
            render json: {
              success: false,
              message: "調整に失敗しました: #{e.message}"
            }, status: :internal_server_error
          end
        end
        
        private
        
        # 最適化エラーメッセージをユーザーフレンドリーに変換
        def parse_optimization_error(error_message)
          # 休閑期間による重複エラー
          if error_message.include?('Time overlap') && error_message.include?('fallow period')
            return '指定した位置には作物を配置できません。休閑期間（28日）を考慮すると、既存の作物と重複してしまいます。別の位置または日付を選択してください。'
          end
          
          # 全ての移動が拒否された
          if error_message.include?('No moves were applied successfully')
            if error_message.include?('Time overlap')
              return '作物を追加できません。選択した位置は既存の作物と重複しています（休閑期間を含む）。空いている場所を選択してください。'
            else
              return '作物を追加できません。栽培計画の制約により、この作物を配置できませんでした。'
            end
          end
          
          # 割り当ての重複エラー
          if error_message.include?('overlap') && error_message.include?('considering')
            return '作物の配置に失敗しました。既存の栽培スケジュールと重複しています。別の時期または圃場を選択してください。'
          end
          
          # Invalid optimization result
          if error_message.include?('Invalid optimization result')
            return '最適化処理でエラーが発生しました。作物の配置位置を変更してもう一度お試しください。'
          end
          
          # デフォルトメッセージ
          '作物の追加に失敗しました。別の位置または日付をお試しください。'
        end
        
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
        
        # Action Cable経由で最適化完了を通知
        def broadcast_optimization_complete(cultivation_plan)
          Rails.logger.info "📡 [Action Cable] Broadcasting optimization complete for plan_id=#{cultivation_plan.id}"
          
          OptimizationChannel.broadcast_to(
            cultivation_plan,
            {
              status: 'adjusted',
              message: '最適化が完了しました',
              total_profit: cultivation_plan.total_profit,
              total_revenue: cultivation_plan.total_revenue,
              total_cost: cultivation_plan.total_cost,
              field_cultivations_count: cultivation_plan.field_cultivations.count
            }
          )
          
          Rails.logger.info "✅ [Action Cable] Broadcast sent successfully"
        rescue StandardError => e
          Rails.logger.error "❌ [Action Cable] Failed to broadcast: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
        
        # 現在の割り当てをAGRR形式に構築
        # @param cultivation_plan [CultivationPlan] 栽培計画
        # @param exclude_ids [Array<Integer>] 除外するfield_cultivationのIDリスト（デフォルト: []）
        def build_current_allocation(cultivation_plan, exclude_ids: [])
          field_schedules = []
          
          Rails.logger.info "🔍 [Build Allocation] field_cultivations count: #{cultivation_plan.field_cultivations.count}"
          Rails.logger.info "🔍 [Build Allocation] exclude_ids: #{exclude_ids.inspect}" if exclude_ids.any?
          
          # 圃場ごとにグループ化
          cultivations_by_field = cultivation_plan.field_cultivations.group_by(&:cultivation_plan_field_id)
          
          Rails.logger.info "🔍 [Build Allocation] cultivations_by_field: #{cultivations_by_field.keys}"
          
          cultivations_by_field.each do |field_id, cultivations|
            field = cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id }
            next unless field
            
            # exclude_idsに含まれる作物を除外
            filtered_cultivations = cultivations.reject { |fc| exclude_ids.include?(fc.id) }
            
            Rails.logger.info "🔍 [Build Allocation] Field #{field_id}: #{cultivations.count} -> #{filtered_cultivations.count} (excluded: #{cultivations.count - filtered_cultivations.count})" if exclude_ids.any?
            
            allocations = filtered_cultivations.map do |fc|
              # 収益とコストを取得
              revenue = fc.optimization_result&.dig('revenue') || 0.0
              cost = fc.estimated_cost || 0.0
              # profitはrevenue - costで計算（agrrコマンドの期待に合わせる）
              profit = revenue - cost
              
              {
                allocation_id: "alloc_#{fc.id}",
                crop_id: fc.cultivation_plan_crop.agrr_crop_id || fc.cultivation_plan_crop.name,
                crop_name: fc.crop_display_name,
                variety: fc.cultivation_plan_crop.name,
                area_used: fc.area,  # agrr optimize adjustが期待するフィールド
                start_date: fc.start_date.to_s,
                completion_date: fc.completion_date.to_s,
                growth_days: fc.cultivation_days || (fc.completion_date - fc.start_date).to_i + 1,
                accumulated_gdd: fc.optimization_result&.dig('accumulated_gdd') || 0.0,
                total_cost: cost,
                expected_revenue: revenue,
                profit: profit  # revenue - costで計算
              }
            end
            
            # 圃場レベルの合計値を計算
            field_total_cost = allocations.sum { |a| a[:total_cost] }
            field_total_revenue = allocations.sum { |a| a[:expected_revenue] }
            field_total_profit = allocations.sum { |a| a[:profit] }
            field_area_used = allocations.sum { |a| a[:area_used] }
            field_utilization_rate = field_area_used / field.area.to_f
            
            field_schedules << {
              field_id: "field_#{field.id}",
              field_name: field.name,
              total_cost: field_total_cost,
              total_revenue: field_total_revenue,
              total_profit: field_total_profit,
              utilization_rate: field_utilization_rate,
              allocations: allocations
            }
          end
          
          # 全体レベルの合計値を計算
          total_cost = field_schedules.sum { |fs| fs[:total_cost] }
          total_revenue = field_schedules.sum { |fs| fs[:total_revenue] }
          total_profit = field_schedules.sum { |fs| fs[:total_profit] }
          
          {
            optimization_result: {
              optimization_id: "opt_#{cultivation_plan.id}",
              total_cost: total_cost,
              total_revenue: total_revenue,
              total_profit: total_profit,
              field_schedules: field_schedules
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
            
            # AGRR形式に変換（stage_requirementsを含む完全な形式）
            crop_data = crop.to_agrr_requirement
            
            # crop_idをcurrent_allocationと一致させる
            crop_data['crop']['crop_id'] = plan_crop.agrr_crop_id || plan_crop.name
            
            crop_data
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
          Rails.logger.info "💾 [Save Adjusted Result] result keys: #{result.keys}"
          Rails.logger.info "💾 [Save Adjusted Result] field_schedules: #{result[:field_schedules]&.count || 'nil'}"
          
          # 全field_schedulesのallocation_idをリスト化して重複チェック
          all_allocation_ids = []
          result[:field_schedules]&.each do |fs|
            fs['allocations']&.each do |alloc|
              all_allocation_ids << alloc['allocation_id']
            end
          end
          
          Rails.logger.info "💾 [Save] Total allocations to create: #{all_allocation_ids.count}"
          Rails.logger.info "💾 [Save] Unique allocations: #{all_allocation_ids.uniq.count}"
          
          if all_allocation_ids.count != all_allocation_ids.uniq.count
            duplicates = all_allocation_ids.select { |id| all_allocation_ids.count(id) > 1 }.uniq
            Rails.logger.error "❌ [Save] 重複したallocation_idが検出されました: #{duplicates}"
          end
          
          # field_schedulesが存在しない場合は何もしない（エラーを避ける）
          unless result[:field_schedules].present?
            Rails.logger.warn "⚠️ [Save Adjusted Result] field_schedules is empty, skipping save"
            return
          end
          
          # トランザクション内で既存データを削除し、新しいデータを作成
          ActiveRecord::Base.transaction do
            # 既存の栽培スケジュールを削除
            cultivation_plan.field_cultivations.destroy_all
            
            # 新しい栽培スケジュールを作成
            result[:field_schedules].each do |field_schedule|
              # agrr optimize adjustの出力形式: {"field"=>{...}, "allocations"=>[...]}
              # agrr optimize allocateの出力形式: {"field_id"=>..., "allocations"=>[...]}
              field_id_str = field_schedule['field_id'] || field_schedule.dig('field', 'field_id')
              
              Rails.logger.info "🔍 [Save] Processing field_schedule: #{field_id_str}"
              
              # field_idから実際のCultivationPlanFieldを取得
              field_id_num = field_id_str&.gsub('field_', '')&.to_i
              unless field_id_num
                Rails.logger.warn "⚠️ [Save] field_id_num is nil for: #{field_schedule['field_id']}"
                next
              end
              
              plan_field = cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id_num }
              unless plan_field
                Rails.logger.warn "⚠️ [Save] plan_field not found for field_id: #{field_id_num}, available: #{cultivation_plan.cultivation_plan_fields.map(&:id)}"
                next
              end
              
              Rails.logger.info "✅ [Save] Found plan_field: #{plan_field.id} (#{plan_field.name})"
              Rails.logger.info "🔍 [Save] allocations count: #{field_schedule['allocations']&.count || 'nil'}"
              Rails.logger.info "🔍 [Save] allocations: #{field_schedule['allocations']&.inspect&.first(300)}"
              
              field_schedule['allocations']&.each do |allocation|
                Rails.logger.info "🔍 [Save] Processing allocation: #{allocation['allocation_id']}, crop_id: #{allocation['crop_id']}"
                
                # crop_idから実際のCultivationPlanCropを取得
                plan_crop = cultivation_plan.cultivation_plan_crops.find do |c|
                  c.agrr_crop_id == allocation['crop_id'] || c.name == allocation['crop_id']
                end
                unless plan_crop
                  Rails.logger.warn "⚠️ [Save] plan_crop not found for crop_id: #{allocation['crop_id']}, available agrr_crop_ids: #{cultivation_plan.cultivation_plan_crops.map(&:agrr_crop_id)}, names: #{cultivation_plan.cultivation_plan_crops.map(&:name)}"
                  next
                end
                
                FieldCultivation.create!(
                  cultivation_plan: cultivation_plan,
                  cultivation_plan_field: plan_field,
                  cultivation_plan_crop: plan_crop,
                  start_date: Date.parse(allocation['start_date']),
                  completion_date: Date.parse(allocation['completion_date']),
                  cultivation_days: (Date.parse(allocation['completion_date']) - Date.parse(allocation['start_date'])).to_i + 1,
                  area: allocation['area_used'] || allocation['area'],
                  estimated_cost: allocation['total_cost'] || allocation['cost'],
                  optimization_result: {
                    revenue: allocation['expected_revenue'] || allocation['revenue'],
                    profit: allocation['profit'],
                    accumulated_gdd: allocation['accumulated_gdd']
                  }
                )
              end
            end
            
            # 最適化結果を更新
            cultivation_plan.update!(
              optimization_summary: result[:summary],
              total_profit: result[:total_profit],
              total_revenue: result[:total_revenue],
              total_cost: result[:total_cost],
              optimization_time: result[:optimization_time],
              algorithm_used: result[:algorithm_used],
              is_optimal: result[:is_optimal],
              status: 'completed'
            )
          end
        end
      end
    end
  end
end

