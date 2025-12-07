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
    
    # 事前に使用されるcrop_idを集約し、findループを回避
    used_crop_ids = Set.new
    result[:field_schedules]&.each do |fs|
      fs['allocations']&.each do |alloc|
        used_crop_ids.add(alloc['crop_id'])
      end
    end
    crop_by_id = Crop.where(id: used_crop_ids.to_a).index_by { |c| c.id.to_s }
    
    # plan内の参照も事前にインデックス化
    plan_fields_by_id = cultivation_plan.cultivation_plan_fields.index_by(&:id)
    plan_crops_by_crop_id = cultivation_plan.cultivation_plan_crops.index_by { |pc| pc.crop.id.to_s }
    
    # 全field_schedulesのallocation_idをリスト化して重複チェック
    all_allocation_ids = []
    result[:field_schedules]&.each do |fs|
      fs['allocations']&.each do |alloc|
        all_allocation_ids << alloc['allocation_id']
      end
    end
    
    Rails.logger.info "💾 [Save] Total allocations in result: #{all_allocation_ids.count}"
    Rails.logger.info "💾 [Save] Unique allocations: #{all_allocation_ids.uniq.count}"
    
    if all_allocation_ids.compact.count != all_allocation_ids.compact.uniq.count
      duplicates = all_allocation_ids.compact.select { |id| all_allocation_ids.count(id) > 1 }.uniq
      Rails.logger.error "❌ [Save] CRITICAL: 重複したallocation_idが検出されました: #{duplicates}"
      Rails.logger.error "❌ [Save] Total allocations: #{all_allocation_ids.count}, Unique(compact): #{all_allocation_ids.compact.uniq.count}"
      raise I18n.t('controllers.agrr_optimization.errors.duplicate_allocation', ids: duplicates.join(', '))
    end
    
    # field_schedulesが存在しない場合はエラーを上げる
    unless result[:field_schedules].present?
      Rails.logger.error "❌ [Save Adjusted Result] CRITICAL: field_schedules is empty"
      Rails.logger.error "❌ [Save Adjusted Result] Result keys: #{result.keys}"
      Rails.logger.error "❌ [Save Adjusted Result] Full result: #{result.inspect}"
      raise I18n.t('controllers.agrr_optimization.errors.result_empty')
    end
    
    # トランザクション内で差分更新（全削除→全作成を廃止）
    ActiveRecord::Base.transaction do
      # ⚠️ reloadしてキャッシュをクリア（ダブル送信対策）
      cultivation_plan.reload
      now = Time.current
      
      # 既存の栽培を取得（idインデックス）
      existing_fcs = cultivation_plan.field_cultivations.to_a
      existing_by_id = existing_fcs.index_by(&:id)
      
      # 結果から望ましいレコード群を正規化
      desired_records = []
      result[:field_schedules].each do |field_schedule|
        field_id = field_schedule['field_id']
        next unless field_id
        plan_field = plan_fields_by_id[field_id]
        unless plan_field
          Rails.logger.error "❌ [Save] CRITICAL: plan_field not found for field_id: #{field_id}"
          Rails.logger.error "❌ [Save] Available field_ids: #{cultivation_plan.cultivation_plan_fields.map(&:id)}"
          Rails.logger.error "❌ [Save] Field schedule: #{field_schedule.inspect}"
          raise I18n.t('controllers.agrr_optimization.errors.field_missing', field_id: field_id)
        end
        
        next unless field_schedule['allocations']&.present?
        field_schedule['allocations'].each do |allocation|
          crop = crop_by_id[allocation['crop_id']]
          unless crop
            Rails.logger.error "❌ [Save] CRITICAL: crop not found for crop_id: #{allocation['crop_id']}"
            Rails.logger.error "❌ [Save] Available crop_ids: #{Crop.pluck(:id)}"
            Rails.logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
            raise I18n.t('controllers.agrr_optimization.errors.crop_missing', crop_id: allocation['crop_id'])
          end
          
          plan_crop = plan_crops_by_crop_id[allocation['crop_id']]
          unless plan_crop
            Rails.logger.error "❌ [Save] CRITICAL: plan_crop not found for crop_id: #{allocation['crop_id']}"
            Rails.logger.error "❌ [Save] Available crop_ids: #{cultivation_plan.cultivation_plan_crops.map { |c| c.crop.id.to_s }}"
            Rails.logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
            raise I18n.t('controllers.agrr_optimization.errors.plan_crop_missing', crop_id: allocation['crop_id'])
          end
          
          begin
            start_date = Date.parse(allocation['start_date'])
          rescue ArgumentError => e
            Rails.logger.error "❌ [Save] Invalid start_date format: #{allocation['start_date'].inspect}"
            raise ArgumentError, I18n.t('controllers.agrr_optimization.errors.start_date_invalid', value: allocation['start_date'].inspect, allocation_id: allocation['allocation_id'])
          end
          
          begin
            completion_date = Date.parse(allocation['completion_date'])
          rescue ArgumentError => e
            Rails.logger.error "❌ [Save] Invalid completion_date format: #{allocation['completion_date'].inspect}"
            raise ArgumentError, I18n.t('controllers.agrr_optimization.errors.completion_date_invalid', value: allocation['completion_date'].inspect, allocation_id: allocation['allocation_id'])
          end
          desired_records << {
            allocation_id: allocation['allocation_id'],
            attrs: {
              cultivation_plan_id: cultivation_plan.id,
              cultivation_plan_field_id: plan_field.id,
              cultivation_plan_crop_id: plan_crop.id,
              start_date: start_date,
              completion_date: completion_date,
              cultivation_days: (completion_date - start_date).to_i + 1,
              area: allocation['area_used'] || allocation['area'],
              estimated_cost: allocation['total_cost'] || allocation['cost'],
              optimization_result: {
                revenue: allocation['expected_revenue'] || allocation['revenue'],
                profit: allocation['profit'],
                accumulated_gdd: allocation['accumulated_gdd']
              },
              updated_at: now,
              created_at: now
            }
          }
        end
      end
      
      # 更新対象/新規作成/削除対象を分類
      desired_with_existing = desired_records.select { |r| r[:allocation_id].present? && existing_by_id.key?(r[:allocation_id]) }
      to_update = desired_with_existing
      to_create = desired_records.reject { |r| r[:allocation_id].present? && existing_by_id.key?(r[:allocation_id]) }
      
      desired_existing_ids = desired_with_existing.map { |r| r[:allocation_id] }
      to_delete_ids = existing_by_id.keys - desired_existing_ids
      
      Rails.logger.info "🛠️ [Save] to_update: #{to_update.size}, to_create: #{to_create.size}, to_delete: #{to_delete_ids.size}"
      
      # 1) 更新（個別 update: 変更のあったもののみ）
      to_update.each do |rec|
        fc = existing_by_id[rec[:allocation_id]]
        fc.update!(rec[:attrs].except(:created_at))
      end
      
      # 2) 新規一括挿入
      if to_create.any?
        insert_rows = to_create.map { |r| r[:attrs] }
        FieldCultivation.insert_all!(insert_rows)
      end
      
      # 3) 削除（紐付く TaskSchedule は field_cultivation_id を null にして保持）
      if to_delete_ids.any?
        TaskSchedule.where(field_cultivation_id: to_delete_ids).update_all(field_cultivation_id: nil)
        FieldCultivation.where(id: to_delete_ids).delete_all
      end
      
      # 使われていない作物を削除（簡易クリーンアップ）
      if used_crop_ids.any?
        used_plan_crop_ids = cultivation_plan.cultivation_plan_crops.select { |pc| used_crop_ids.include?(pc.crop.id.to_s) }.map(&:id)
        unused_plan_crops = cultivation_plan.cultivation_plan_crops.where.not(id: used_plan_crop_ids)
        if unused_plan_crops.exists?
          Rails.logger.info "🗑️ [Save] 使われていない作物を削除: #{unused_plan_crops.pluck(:name).join(', ')}"
          unused_plan_crops.delete_all
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
    # ブロードキャストの失敗はデータベーストランザクションの成功に影響を与えない
    # データベースへの保存は既に完了しているため、エラーをログに記録するのみ
    Rails.logger.error "❌ [Action Cable] Broadcast failed for plan_id=#{cultivation_plan.id}: #{e.class} - #{e.message}"
    Rails.logger.error "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
    # エラーを再発生させない（データベーストランザクションは成功しているため）
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
    
    # 関連を事前読込してN+1を防止
    preloaded_plan = CultivationPlan.includes(
      :cultivation_plan_fields,
      { cultivation_plan_crops: :crop },
      { field_cultivations: [:cultivation_plan_field, { cultivation_plan_crop: :crop }] }
    ).find(cultivation_plan.id)
    cultivation_plan = preloaded_plan
    
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
    
    # 気象データの取得は、effective_planning_endを計算した後に行う
    # （計画期間外でも修正ができるように、必要な範囲の気温データを確保するため）
    farm = cultivation_plan.farm
    unless farm.weather_location
      return {
        success: false,
        message: I18n.t('api.errors.no_weather_data'),
        status: :not_found
      }
    end
    
    # 計画期間を制約として使用しないように、現在の作付の範囲に基づいて動的に計算
    # 計画期間はadjust処理の必須パラメータだが、制約として使用しないように広い範囲を設定
    # 気象データ取得前に計算して、必要な気温データの範囲を確定する
    begin
      effective_planning_start, effective_planning_end = calculate_effective_planning_period(
        cultivation_plan,
        current_allocation,
        moves
      )
    rescue ArgumentError => e
      Rails.logger.error "❌ [Adjust] Invalid date format in planning period calculation: #{e.message}"
      return {
        success: false,
        message: I18n.t('api.errors.common.invalid_date_format', message: e.message),
        status: :bad_request
      }
    rescue StandardError => e
      Rails.logger.error "❌ [Adjust] Failed to calculate planning period: #{e.class.name}: #{e.message}"
      Rails.logger.error "❌ [Adjust] Backtrace: #{e.backtrace.first(10).join("\n")}"
      return {
        success: false,
        message: I18n.t('api.errors.optimization.calculate_period_failed', message: e.message),
        status: :internal_server_error
      }
    end
    
    # 気象データを取得（effective_planning_endをtarget_end_dateとして使用）
    # 計画期間外でも修正ができるように、必要な範囲の気温データを確保する
    begin
      weather_location = farm.weather_location
      unless weather_location
        raise WeatherPredictionService::WeatherDataNotFoundError,
              "気象データがありません。農場にWeatherLocationが設定されていません。"
      end

      weather_prediction_service = WeatherPredictionService.new(
        weather_location: weather_location,
        farm: farm
      )
      
      # effective_planning_endをtarget_end_dateとして使用して既存の予測データを確認
      existing_prediction = weather_prediction_service.get_existing_prediction(
        target_end_date: effective_planning_end,
        cultivation_plan: cultivation_plan
      )
      if existing_prediction
        weather_data = existing_prediction[:data]
        Rails.logger.info "♻️ [Adjust] Using existing prediction data (target_end_date: #{effective_planning_end})"
      else
        # 既存の予測データが不足している場合は、effective_planning_endまで新規予測を実行
        Rails.logger.info "🔮 [Adjust] Generating new prediction data (target_end_date: #{effective_planning_end})"
        weather_info = weather_prediction_service.predict_for_cultivation_plan(
          cultivation_plan,
          target_end_date: effective_planning_end
        )
        weather_data = weather_info[:data]
      end
    rescue => e
      Rails.logger.error "❌ [Adjust] Failed to get weather data: #{e.message}"
      return {
        success: false,
        message: I18n.t('api.errors.common.weather_fetch_failed', message: e.message),
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
    
    # 計画期間を制約として使用しないように、現在の作付の範囲に基づいて動的に計算
    # 計画期間はadjust処理の必須パラメータだが、制約として使用しないように広い範囲を設定
    begin
      effective_planning_start, effective_planning_end = calculate_effective_planning_period(
        cultivation_plan,
        current_allocation,
        moves
      )
    rescue ArgumentError => e
      Rails.logger.error "❌ [Adjust] Invalid date format in planning period calculation: #{e.message}"
      return {
        success: false,
        message: I18n.t('api.errors.common.invalid_date_format', message: e.message),
        status: :bad_request
      }
    rescue StandardError => e
      Rails.logger.error "❌ [Adjust] Failed to calculate planning period: #{e.class.name}: #{e.message}"
      Rails.logger.error "❌ [Adjust] Backtrace: #{e.backtrace.first(10).join("\n")}"
      return {
        success: false,
        message: I18n.t('api.errors.optimization.calculate_period_failed', message: e.message),
        status: :internal_server_error
      }
    end
    
    # agrr optimize adjust を実行
    begin
      perf_before_adjust = Time.current
      Rails.logger.info "⏱️ [PERF] AdjustGateway.adjust() 呼び出し開始"
      Rails.logger.info "📅 [Adjust] 計画期間: #{effective_planning_start} 〜 #{effective_planning_end} (制約として使用しない)"
      adjust_gateway = Agrr::AdjustGateway.new
      result = adjust_gateway.adjust(
        current_allocation: current_allocation,
        moves: moves,
        fields: fields,
        crops: crops,
        weather_data: weather_data,
        planning_start: effective_planning_start,
        planning_end: effective_planning_end,
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
          message: I18n.t('optimization.messages.adjust_completed'),
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
          message: I18n.t('api.errors.optimization.result_empty'),
          status: :internal_server_error
        }
      end
    rescue ArgumentError => e
      Rails.logger.error "❌ [Adjust] Invalid date format: #{e.message}"
      return {
        success: false,
        message: I18n.t('api.errors.common.invalid_date_format', message: e.message),
        status: :bad_request
      }
    rescue Agrr::BaseGateway::ExecutionError => e
      Rails.logger.error "❌ [Adjust] Failed to adjust: #{e.message}"
      # エラー時はデータを削除しない
      return {
        success: false,
        message: I18n.t('api.errors.optimization.adjust_failed', message: e.message),
        status: :internal_server_error
      }
    end
  end
  
  # 計画期間を制約として使用しないように、現在の作付の範囲に基づいて動的に計算
  # @param cultivation_plan [CultivationPlan] 栽培計画
  # @param current_allocation [Hash] 現在の割り当てデータ
  # @param moves [Array<Hash>] 移動指示のリスト
  # @return [Array<Date, Date>] [effective_planning_start, effective_planning_end]
  def calculate_effective_planning_period(cultivation_plan, current_allocation, moves)
    # 現在の作付の日付範囲を取得
    all_dates = []
    
    # 現在の割り当てから日付を抽出
    if current_allocation[:optimization_result] && current_allocation[:optimization_result][:field_schedules]
      current_allocation[:optimization_result][:field_schedules].each do |field_schedule|
        field_schedule[:allocations]&.each do |allocation|
          if allocation[:start_date]
            begin
              all_dates << Date.parse(allocation[:start_date])
            rescue ArgumentError => e
              Rails.logger.error "❌ [Calculate Planning Period] Invalid start_date format: #{allocation[:start_date].inspect}"
              raise ArgumentError, I18n.t('controllers.agrr_optimization.errors.start_date_invalid', value: allocation[:start_date].inspect, allocation_id: allocation[:allocation_id])
            end
          end
          if allocation[:completion_date]
            begin
              all_dates << Date.parse(allocation[:completion_date])
            rescue ArgumentError => e
              Rails.logger.error "❌ [Calculate Planning Period] Invalid completion_date format: #{allocation[:completion_date].inspect}"
              raise ArgumentError, I18n.t('controllers.agrr_optimization.errors.completion_date_invalid', value: allocation[:completion_date].inspect, allocation_id: allocation[:allocation_id])
            end
          end
        end
      end
    end
    
    # 移動指示から新しい日付を抽出
    moves.each do |move|
      if move[:to_start_date]
        begin
          all_dates << Date.parse(move[:to_start_date])
        rescue ArgumentError => e
          Rails.logger.error "❌ [Calculate Planning Period] Invalid to_start_date format: #{move[:to_start_date].inspect}"
          raise ArgumentError, "不正な移動先開始日付形式です: #{move[:to_start_date].inspect} (move: #{move.inspect})"
        end
      end
    end
    
    # データベースからも現在の作付の日付を取得（フォールバック）
    if all_dates.empty?
      cultivation_plan.field_cultivations.each do |fc|
        all_dates << fc.start_date if fc.start_date
        all_dates << fc.completion_date if fc.completion_date
      end
    end
    
    # 日付範囲を計算（余裕を持たせる）
    if all_dates.any?
      min_date = all_dates.min
      max_date = all_dates.max
      # 前後1年分の余裕を持たせる（計画期間を制約として使用しないため）
      effective_start = (min_date - 365).beginning_of_year
      effective_end = (max_date + 365).end_of_year
    else
      # 作付がない場合は計画期間を使用（フォールバック）
      effective_start = cultivation_plan.planning_start_date || Date.current

      # planning_end_dateが設定されている場合はそれを使用
      # 設定されていない場合は、effective_startを基準に2年後の年末を計算
      # これにより、effective_startが未来の日付でも常にeffective_start <= effective_endが保証される
      effective_end = cultivation_plan.planning_end_date || (effective_start + 2.years).end_of_year
      
      # 念のため、effective_start > effective_endの場合は調整
      if effective_start > effective_end
        effective_end = (effective_start + 2.years).end_of_year
      end
    end
    
    [effective_start, effective_end]
  end
end

