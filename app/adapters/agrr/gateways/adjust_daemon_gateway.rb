# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      class AdjustDaemonGateway < BaseGatewayV2
        # agrr optimize adjust コマンドを実行して既存の割り当てを手修正
        # @param current_allocation [Hash] 現在の割り当てデータ（agrr optimize allocateの出力形式）
        # @param moves [Array<Hash>] 移動指示のリスト
        # @param fields [Array<Hash>] 圃場設定
        # @param crops [Array<Hash>] 作物設定
        # @param weather_data [Hash] 気象データ
        # @param planning_start [Date] 計画開始日
        # @param planning_end [Date] 計画終了日
        # @param interaction_rules [Hash, nil] 交互作用ルール（オプション）
        # @param objective [String] 最適化目標（'maximize_profit' or 'minimize_cost'）
        # @param max_time [Integer, nil] 最大計算時間（秒）
        # @param enable_parallel [Boolean] 並列処理を有効化
        # @return [Hash] 調整後の割り当てデータ
        def adjust(current_allocation:, moves:, fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          perf_start = Time.current
          Rails.logger.info "🔧 [AGRR Adjust] Adjusting allocation: #{moves.count} move(s)"
          Rails.logger.info "⏱️ [PERF Gateway] adjust() 開始"

          # 各種ファイルを作成
          perf_before_files = Time.current
          allocation_file = write_temp_file(current_allocation, prefix: "current_allocation")
          moves_file = write_temp_file({ "moves" => moves }, prefix: "moves")
          fields_file = write_temp_file({ "fields" => fields }, prefix: "fields")
          crops_file = write_temp_file({ "crops" => crops }, prefix: "crops")
          weather_file = write_temp_file(weather_data, prefix: "weather")
          perf_after_files = Time.current
          Rails.logger.info "⏱️ [PERF Gateway] ファイル作成完了: #{((perf_after_files - perf_before_files) * 1000).round(2)}ms"

          # デバッグ用にファイルを保存（本番環境以外のみ）
          unless Rails.env.production?
            debug_dir = Rails.root.join("tmp/debug")
            FileUtils.mkdir_p(debug_dir)
            debug_allocation_path = debug_dir.join("adjust_allocation_#{Time.current.to_i}.json")
            debug_moves_path = debug_dir.join("adjust_moves_#{Time.current.to_i}.json")
            debug_fields_path = debug_dir.join("adjust_fields_#{Time.current.to_i}.json")
            debug_crops_path = debug_dir.join("adjust_crops_#{Time.current.to_i}.json")
            debug_weather_path = debug_dir.join("adjust_weather_#{Time.current.to_i}.json")
            FileUtils.cp(allocation_file.path, debug_allocation_path)
            FileUtils.cp(moves_file.path, debug_moves_path)
            FileUtils.cp(fields_file.path, debug_fields_path)
            FileUtils.cp(crops_file.path, debug_crops_path)
            FileUtils.cp(weather_file.path, debug_weather_path)
            Rails.logger.info "📁 [AGRR Adjust] Debug allocation saved to: #{debug_allocation_path}"
            Rails.logger.info "📁 [AGRR Adjust] Debug moves saved to: #{debug_moves_path}"
            Rails.logger.info "📁 [AGRR Adjust] Debug fields saved to: #{debug_fields_path}"
            Rails.logger.info "📁 [AGRR Adjust] Debug crops saved to: #{debug_crops_path}"
            Rails.logger.info "📁 [AGRR Adjust] Debug weather saved to: #{debug_weather_path}"
          end

          begin
            command_args = [
              "dummy_path", # Not used in V2
              "optimize",
              "adjust",
              "--current-allocation", allocation_file.path,
              "--moves", moves_file.path,
              "--fields-file", fields_file.path,
              "--crops-file", crops_file.path,
              "--planning-start", planning_start.to_s,
              "--planning-end", planning_end.to_s,
              "--weather-file", weather_file.path,
              "--format", "json"
            ]

            # オプションのinteraction-rules-fileを追加
            if interaction_rules
              rules_file = write_temp_file(interaction_rules, prefix: "interaction_rules")
              command_args += [ "--interaction-rules-file", rules_file.path ]

              unless Rails.env.production?
                debug_rules_path = debug_dir.join("adjust_rules_#{Time.current.to_i}.json")
                FileUtils.cp(rules_file.path, debug_rules_path)
                Rails.logger.info "📁 [AGRR Adjust] Debug rules saved to: #{debug_rules_path}"
              end
            end

            # オプションのmax-timeを追加
            if max_time
              command_args += [ "--max-time", max_time.to_s ]
            end

            # enable-parallelオプションはagrr optimize adjustではサポートされていない

            perf_before_exec = Time.current
            Rails.logger.info "⏱️ [PERF Gateway] Pythonコマンド実行開始"
            Rails.logger.info "⏱️ [PERF Gateway] コマンド: #{command_args.join(' ')}"
            result = execute_command(*command_args)
            perf_after_exec = Time.current
            Rails.logger.info "⏱️ [PERF Gateway] Pythonコマンド実行完了: #{((perf_after_exec - perf_before_exec) * 1000).round(2)}ms"

            perf_before_parse = Time.current
            # BaseGatewayV2のexecute_commandは既にJSONをパース済み
            parsed = parse_adjust_result(result)
            perf_after_parse = Time.current
            Rails.logger.info "⏱️ [PERF Gateway] 結果パース完了: #{((perf_after_parse - perf_before_parse) * 1000).round(2)}ms"

            perf_end = Time.current
            Rails.logger.info "⏱️ [PERF Gateway] === Gateway合計 ==="
            Rails.logger.info "⏱️ [PERF Gateway] 全体: #{((perf_end - perf_start) * 1000).round(2)}ms"
            Rails.logger.info "⏱️ [PERF Gateway] - ファイル作成: #{((perf_after_files - perf_before_files) * 1000).round(2)}ms"
            Rails.logger.info "⏱️ [PERF Gateway] - Python実行: #{((perf_after_exec - perf_before_exec) * 1000).round(2)}ms"
            Rails.logger.info "⏱️ [PERF Gateway] - 結果パース: #{((perf_after_parse - perf_before_parse) * 1000).round(2)}ms"
            Rails.logger.info "✅ [AGRR Adjust] Adjustment completed: fields=#{parsed[:field_schedules].count}, profit=¥#{parsed[:total_profit]}"

            parsed
          ensure
            allocation_file.close
            allocation_file.unlink
            moves_file.close
            moves_file.unlink
            fields_file.close
            fields_file.unlink
            crops_file.close
            crops_file.unlink
            weather_file.close
            weather_file.unlink
            if interaction_rules && rules_file
              rules_file.close
              rules_file.unlink
            end
          end
        end

        private

        def parse_adjust_result(raw_result)
          optimization = raw_result["optimization_result"]
          summary = raw_result["summary"]

          # agrr optimize adjustの出力形式を allocate と同じ形式に変換
          # adjust: {"field": {"field_id": "..."}, "allocations": [{"crop": {...}, ...}]}
          # allocate: {"field_id": "...", "allocations": [{...}]}
          field_schedules = optimization["field_schedules"]&.map do |fs|
            field_data = fs["field"] || {}
            allocations = fs["allocations"]&.map do |alloc|
              # cropデータをフラット化
              crop_data = alloc["crop"] || {}
              alloc.except("crop").merge(crop_data)
            end || []

            {
              "field_id" => field_data["field_id"] || fs["field_id"],
              "field_name" => field_data["name"] || fs["field_name"],
              "allocations" => allocations
            }
          end || []

          {
            optimization_id: optimization["optimization_id"],
            algorithm_used: optimization["algorithm_used"],
            is_optimal: optimization["is_optimal"],
            optimization_time: optimization["optimization_time"],
            total_cost: optimization["total_cost"],
            total_revenue: optimization["total_revenue"],
            total_profit: optimization["total_profit"],
            field_schedules: field_schedules,
            crop_areas: optimization["crop_areas"],
            summary: summary,
            raw: raw_result
          }
        end
      end
    end
  end
end
