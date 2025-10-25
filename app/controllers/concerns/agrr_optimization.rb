# frozen_string_literal: true

# AGRR最適化エンジンとの統合機能を提供するConcern
#
# このConcernは以下の機能を提供します:
# - 現在の割り当てをAGRR形式に変換
# - 圃場・作物設定を構築
# - 交互作用ルールを構築
# - 最適化結果をデータベースに保存
module AgrrOptimization
  extend ActiveSupport::Concern
  
  
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
    
    # 全ての圃場を処理（field_cultivationsが0件でも含める）
    cultivation_plan.cultivation_plan_fields.each do |field|
      field_id = field.id
      cultivations = cultivations_by_field[field_id] || []
      
      # exclude_idsに含まれる作物を除外
      filtered_cultivations = cultivations.reject { |fc| exclude_ids.include?(fc.id) }
      
      Rails.logger.info "🔍 [Build Allocation] Field #{field_id}: #{cultivations.count} -> #{filtered_cultivations.count} (excluded: #{cultivations.count - filtered_cultivations.count})" if exclude_ids.any?
      
      allocations = filtered_cultivations.map do |fc|
        # 収益とコストを取得
        revenue = fc.optimization_result&.dig('revenue') || 0.0
        cost = fc.estimated_cost || 0.0
        # profitはrevenue - costで計算
        profit = revenue - cost
        
        # AGRR CLI側のcrop_idはRails側のcrop.idを使用
        crop_id = fc.cultivation_plan_crop.crop.id.to_s
        
        {
          allocation_id: fc.id,
          crop_id: crop_id,
          crop_name: fc.crop_display_name,
          variety: fc.cultivation_plan_crop.variety,
          area_used: fc.area,
          start_date: fc.start_date.to_s,
          completion_date: fc.completion_date.to_s,
          growth_days: fc.cultivation_days || (fc.completion_date - fc.start_date).to_i + 1,
          accumulated_gdd: fc.optimization_result&.dig('accumulated_gdd') || 0.0,
          total_cost: cost,
          expected_revenue: revenue,
          profit: profit
        }
      end
      
      # 圃場レベルの合計値を計算
      field_total_cost = allocations.sum { |a| a[:total_cost] }
      field_total_revenue = allocations.sum { |a| a[:expected_revenue] }
      field_total_profit = allocations.sum { |a| a[:profit] }
      field_area_used = allocations.sum { |a| a[:area_used] }
      field_utilization_rate = field_area_used / field.area.to_f
      
      field_schedules << {
        field_id: field.id,
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
        field_id: field.id,
        name: field.name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost
      }
    end
  end
  
  # 作物設定を構築
  def build_crops_config(cultivation_plan)
    cultivation_plan.cultivation_plan_crops.map do |plan_crop|
      # 元のCropを直接参照
      crop = plan_crop.crop
      
      # AGRR形式に変換（stage_requirementsを含む完全な形式）
      crop_data = crop.to_agrr_requirement
      
      # AGRR CLI側のcrop_idはRails側のcrop.idを使用
      crop_data['crop']['crop_id'] = crop.id.to_s
      
      crop_data
    end.compact
  end
  
  # 交互作用ルールを構築
  def build_interaction_rules(cultivation_plan)
    # 作物グループのマッピング
    crop_groups = {}
    cultivation_plan.cultivation_plan_crops.each do |plan_crop|
      # 元のCropを直接参照
      crop = plan_crop.crop
      
      crop_id = crop.id.to_s
      crop_groups[crop_id] = crop.groups
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
  
  # 調整結果をデータベースに保存
  #
  # 【重要】このメソッドは既存のFieldCultivationを全削除してから新規作成する
  # - add_cropで作成したtemp_cultivationも削除される
  # - agrr optimize adjustの結果のみがDBに保存される
  # - これにより、allocation_idの重複や一時データの残留を防ぐ
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
      Rails.logger.error "❌ [Save] CRITICAL: 重複したallocation_idが検出されました: #{duplicates}"
      Rails.logger.error "❌ [Save] Total allocations: #{all_allocation_ids.count}, Unique: #{all_allocation_ids.uniq.count}"
      raise "重複したallocation_idが検出されました: #{duplicates.join(', ')}"
    end
    
    # field_schedulesが存在しない場合はエラーを上げる
    unless result[:field_schedules].present?
      Rails.logger.error "❌ [Save Adjusted Result] CRITICAL: field_schedules is empty"
      Rails.logger.error "❌ [Save Adjusted Result] Result keys: #{result.keys}"
      Rails.logger.error "❌ [Save Adjusted Result] Full result: #{result.inspect}"
      raise "最適化結果が空です: field_schedules が存在しません"
    end
    
    # トランザクション内で既存データを削除し、新しいデータを作成
    ActiveRecord::Base.transaction do
      # ⭐ 既存の栽培スケジュールを全削除
      # temp_cultivationも含め、全てのFieldCultivationを削除
      # これにより、agrrの最適化結果のみがDBに残る
      
      # ⚠️ 重要: reloadしてキャッシュをクリア（ダブル送信対策）
      cultivation_plan.reload
      existing_count = cultivation_plan.field_cultivations.count
      Rails.logger.info "🗑️ [Save] 既存のfield_cultivations削除開始: #{existing_count}件"
      cultivation_plan.field_cultivations.destroy_all
      Rails.logger.info "✅ [Save] 既存のfield_cultivations削除完了"
      
      # AGRR結果に含まれる作物IDを収集
      used_crop_ids = Set.new
      result[:field_schedules].each do |field_schedule|
        field_schedule['allocations']&.each do |allocation|
          used_crop_ids.add(allocation['crop_id'])
        end
      end
      
      # 使われていない作物を削除（ゴミデータのクリーンアップ）
      unused_crops = cultivation_plan.cultivation_plan_crops.reject do |crop|
        used_crop_ids.include?(crop.crop.id.to_s)
      end
      
      if unused_crops.any?
        Rails.logger.info "🗑️ [Save] 使われていない作物を削除: #{unused_crops.map(&:name).join(', ')}"
        unused_crops.each(&:destroy)
      end
      
      # 新しい栽培スケジュールを作成
      result[:field_schedules].each do |field_schedule|
        field_id = field_schedule['field_id']
        
        next unless field_id
        
        plan_field = cultivation_plan.cultivation_plan_fields.find { |f| f.id == field_id }
        unless plan_field
          Rails.logger.error "❌ [Save] CRITICAL: plan_field not found for field_id: #{field_id}"
          Rails.logger.error "❌ [Save] Available field_ids: #{cultivation_plan.cultivation_plan_fields.map(&:id)}"
          Rails.logger.error "❌ [Save] Field schedule: #{field_schedule.inspect}"
          raise "圃場が見つかりません: field_id=#{field_id}"
        end
        
        # allocationsが存在しないか空の場合は、このfield_scheduleをスキップ
        next unless field_schedule['allocations']&.present?
        
        field_schedule['allocations']&.each do |allocation|
          
          # AGRR CLI側のcrop_idはRails側のcrop.idを使用
          crop = Crop.find_by(id: allocation['crop_id'])
          unless crop
            Rails.logger.error "❌ [Save] CRITICAL: crop not found for crop_id: #{allocation['crop_id']}"
            Rails.logger.error "❌ [Save] Available crop_ids: #{Crop.pluck(:id)}"
            Rails.logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
            raise "作物が見つかりません: crop_id=#{allocation['crop_id']}"
          end
          
          plan_crop = cultivation_plan.cultivation_plan_crops.find do |c|
            c.crop.id.to_s == allocation['crop_id']
          end
          unless plan_crop
            Rails.logger.error "❌ [Save] CRITICAL: plan_crop not found for crop_id: #{allocation['crop_id']}"
            Rails.logger.error "❌ [Save] Available crop_ids: #{cultivation_plan.cultivation_plan_crops.map { |c| c.crop.id.to_s }}"
            Rails.logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
            raise "作付け計画作物が見つかりません: crop_id=#{allocation['crop_id']}"
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
          Rails.logger.info "✅ [Save] 新規field_cultivation作成: #{plan_crop.name}"
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
      
      # トランザクション完了後の件数確認
      final_count = cultivation_plan.field_cultivations.count
      Rails.logger.info "📊 [Save] トランザクション完了: 最終的なfield_cultivations件数 = #{final_count}"
    end
  end
  
  # Action Cable経由で最適化完了を通知
  def broadcast_optimization_complete(cultivation_plan)
    Rails.logger.info "📡 [Action Cable] Broadcasting optimization complete for plan_id=#{cultivation_plan.id}"
    
    # チャンネルクラスを決定（plan_typeに基づく）
    channel_class = if cultivation_plan.plan_type_public?
                      OptimizationChannel
                    else
                      PlansOptimizationChannel
                    end
    
    Rails.logger.info "📡 [Action Cable] Using channel: #{channel_class.name}"
    
    channel_class.broadcast_to(
      cultivation_plan,
      {
        status: 'completed',
        message: I18n.t('optimization.messages.completed'),
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
  
  
  # DBに保存された天気データを使って調整を実行
  # 
  # このメソッドは天気予測を再実行せず、DBに保存された予測データを再利用する
  # これにより、adjust処理が高速化され、不要な予測処理を避けることができる
  #
  # @param cultivation_plan [CultivationPlan] 栽培計画
  # @param moves [Array<Hash>] 移動指示の配列
  # @return [Hash] 調整結果 { success: true/false, ... }
  def adjust_with_db_weather(cultivation_plan, moves)
    perf_start = Time.current
    Rails.logger.info "⏱️ [PERF] adjust_with_db_weather() 開始: #{perf_start}"
    
    perf_db_load = Time.current
    Rails.logger.info "⏱️ [PERF] DB読み込み完了: #{((perf_db_load - perf_start) * 1000).round(2)}ms"
    
    if moves.empty?
      # 空の移動指示の場合は調整不要で成功
      Rails.logger.info "ℹ️ [Adjust] 移動指示が空のため調整をスキップします"
      return {
        success: true,
        message: '調整不要（移動指示なし）'
      }
    end
    
    # 現在の割り当てをAGRR形式に変換
    perf_before_allocation = Time.current
    current_allocation = build_current_allocation(cultivation_plan)
    perf_after_allocation = Time.current
    Rails.logger.info "⏱️ [PERF] 割り当てデータ構築: #{((perf_after_allocation - perf_before_allocation) * 1000).round(2)}ms"
    
    # 圃場と作物の設定を構築
    fields = build_fields_config(cultivation_plan)
    perf_after_fields = Time.current
    Rails.logger.info "⏱️ [PERF] 圃場設定構築: #{((perf_after_fields - perf_after_allocation) * 1000).round(2)}ms"
    
    crops = build_crops_config(cultivation_plan)
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
      Rails.logger.info "📁 [Adjust] Debug current_allocation saved to: #{debug_current_allocation_path}"
      Rails.logger.info "📁 [Adjust] Debug moves saved to: #{debug_moves_path}"
      Rails.logger.info "📁 [Adjust] Debug fields saved to: #{debug_fields_path}"
      Rails.logger.info "📁 [Adjust] Debug crops saved to: #{debug_crops_path}"
    end
    
    # 気象データを取得
    farm = cultivation_plan.farm
    unless farm.weather_location
      return {
        success: false,
        message: '気象データがありません',
        status: :not_found
      }
    end
    
    # 天気予測データを取得（既存データまたは新規予測）
    begin
      weather_prediction_service = WeatherPredictionService.new(farm)
      
      # 既存の予測データを確認
      existing_prediction = weather_prediction_service.get_existing_prediction(cultivation_plan: cultivation_plan)
      if existing_prediction
        weather_data = existing_prediction[:data]
        Rails.logger.info "♻️ [Adjust] Using existing prediction data"
      else
        # 新規予測を実行
        Rails.logger.info "🔮 [Adjust] Generating new prediction data"
        weather_info = weather_prediction_service.predict_for_cultivation_plan(cultivation_plan)
        weather_data = weather_info[:data]
      end
    rescue => e
      Rails.logger.error "❌ [Adjust] Failed to get weather data: #{e.message}"
      return {
        success: false,
        message: "気象データの取得に失敗しました: #{e.message}",
        status: :internal_server_error
      }
    end
    
    # 古い保存形式（ネスト構造）の場合は修正
    if weather_data['data'].is_a?(Hash) && weather_data['data']['data'].is_a?(Array)
      weather_data = weather_data['data']
    end
    
    # 交互作用ルールを構築
    perf_before_rules = Time.current
    interaction_rules = build_interaction_rules(cultivation_plan)
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
        planning_start: cultivation_plan.planning_start_date,
        planning_end: cultivation_plan.planning_end_date,
        interaction_rules: interaction_rules.empty? ? nil : { 'rules' => interaction_rules },
        objective: 'maximize_profit',
        enable_parallel: true
      )
      
      perf_after_adjust = Time.current
      Rails.logger.info "⏱️ [PERF] AdjustGateway.adjust() 完了: #{((perf_after_adjust - perf_before_adjust) * 1000).round(2)}ms"
      
      # 結果が正常に取得できた場合のみデータベースに保存
      if result && result[:field_schedules].present?
        perf_before_save = Time.current
        save_adjusted_result(cultivation_plan, result)
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
        broadcast_optimization_complete(cultivation_plan)
        
        return {
          success: true,
          message: '調整が完了しました',
          cultivation_plan: {
            id: cultivation_plan.id,
            total_profit: result[:total_profit],
            field_cultivations_count: cultivation_plan.field_cultivations.count
          }
        }
      else
        Rails.logger.error "❌ [Adjust] Result has no field_schedules"
        return {
          success: false,
          message: "調整結果が空です",
          status: :internal_server_error
        }
      end
    rescue Agrr::BaseGateway::ExecutionError => e
      Rails.logger.error "❌ [Adjust] Failed to adjust: #{e.message}"
      # エラー時はデータを削除しない
      return {
        success: false,
        message: "調整に失敗しました: #{e.message}",
        status: :internal_server_error
      }
    end
  end
end

