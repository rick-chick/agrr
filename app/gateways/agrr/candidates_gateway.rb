# frozen_string_literal: true

module Agrr
  class CandidatesGateway < BaseGatewayV2
    # agrr optimize candidates コマンドを実行して最適な作付候補を取得
    # @param current_allocation [Hash] 現在の割り当てデータ（agrr optimize allocateの出力形式）
    # @param fields [Array<Hash>] 圃場設定
    # @param crops [Array<Hash>] 作物設定
    # @param target_crop [String] 候補を生成する対象作物のID
    # @param weather_data [Hash] 気象データ
    # @param planning_start [Date] 計画開始日
    # @param planning_end [Date] 計画終了日
    # @param interaction_rules [Hash, nil] 交互作用ルール（オプション）
    # @return [Array<Hash>] 候補リスト（field_id, start_date, profit 等を含む）
    def candidates(current_allocation:, fields:, crops:, target_crop:, weather_data:, planning_start:, planning_end:, interaction_rules: nil)
      Rails.logger.info "🔍 [AGRR Candidates] Generating candidates for crop: #{target_crop}"
      Rails.logger.info "📅 [AGRR Candidates] Planning period: #{planning_start} ~ #{planning_end}"

      # 各種ファイルを作成
      allocation_file = write_temp_file(current_allocation, prefix: 'candidates_allocation')
      fields_file = write_temp_file({ 'fields' => fields }, prefix: 'candidates_fields')
      crops_file = write_temp_file({ 'crops' => crops }, prefix: 'candidates_crops')
      weather_file = write_temp_file(weather_data, prefix: 'candidates_weather')
      output_file = Tempfile.new(['candidates_output', '.json'])

      begin
        command_args = [
          'dummy_path',
          'optimize',
          'candidates',
          '--allocation', allocation_file.path,
          '--fields-file', fields_file.path,
          '--crops-file', crops_file.path,
          '--target-crop', target_crop.to_s,
          '--planning-start', planning_start.to_s,
          '--planning-end', planning_end.to_s,
          '--weather-file', weather_file.path,
          '--output', output_file.path,
          '--format', 'json'
        ]

        if interaction_rules
          rules_file = write_temp_file(interaction_rules, prefix: 'candidates_rules')
          command_args += ['--interaction-rules-file', rules_file.path]
        end

        # デバッグ用にファイルを保存（本番環境以外のみ）
        unless Rails.env.production?
          debug_dir = Rails.root.join('tmp/debug')
          FileUtils.mkdir_p(debug_dir)
          ts = Time.current.to_i
          FileUtils.cp(allocation_file.path, debug_dir.join("candidates_allocation_#{ts}.json"))
          FileUtils.cp(fields_file.path, debug_dir.join("candidates_fields_#{ts}.json"))
          FileUtils.cp(crops_file.path, debug_dir.join("candidates_crops_#{ts}.json"))
          FileUtils.cp(weather_file.path, debug_dir.join("candidates_weather_#{ts}.json"))
          if interaction_rules && rules_file
            FileUtils.cp(rules_file.path, debug_dir.join("candidates_rules_#{ts}.json"))
          end
          Rails.logger.info "📁 [AGRR Candidates] Debug files saved to: #{debug_dir}/candidates_*_#{ts}.json"
        end

        # candidatesコマンドはstdoutではなく--outputファイルに結果を書き出すため、
        # stdoutのJSONパースをスキップする
        execute_command(*command_args, parse_json: false)

        # デバッグ用にoutputファイルも保存
        unless Rails.env.production?
          if File.exist?(output_file.path) && File.size(output_file.path) > 0
            FileUtils.cp(output_file.path, debug_dir.join("candidates_output_#{ts}.json"))
            Rails.logger.info "📁 [AGRR Candidates] Debug output saved to: #{debug_dir}/candidates_output_#{ts}.json"
          else
            Rails.logger.info "📁 [AGRR Candidates] Output file is empty (no candidates)"
          end
        end

        parsed = parse_candidates_result(output_file)

        Rails.logger.info "✅ [AGRR Candidates] Found #{parsed.length} candidate(s)"
        parsed
      ensure
        allocation_file.close
        allocation_file.unlink
        fields_file.close
        fields_file.unlink
        crops_file.close
        crops_file.unlink
        weather_file.close
        weather_file.unlink
        output_file.close
        output_file.unlink
        if interaction_rules && rules_file
          rules_file.close
          rules_file.unlink
        end
      end
    end

    private

    def parse_candidates_result(output_file)
      # --outputファイルから候補を読み取る
      candidates = if File.exist?(output_file.path) && File.size(output_file.path) > 0
                     raw = JSON.parse(File.read(output_file.path))
                     case raw
                     when Hash then raw['candidates'] || []
                     when Array then raw
                     else []
                     end
                   else
                     []
                   end

      candidates.filter_map do |c|
        # start_date の datetime 形式を date のみに正規化（"2025-01-01T00:00:00" → "2025-01-01"）
        start_date = normalize_date(c['start_date'])
        completion_date = normalize_date(c['completion_date'])

        # candidate_type に関わらず共通フィールドを抽出
        # profit は expected_profit をフォールバックとして使用
        profit = c['profit'] || c['expected_profit']

        {
          field_id: c['field_id'],
          field_name: c['field_name'],
          candidate_type: c['candidate_type'],
          start_date: start_date,
          completion_date: completion_date,
          profit: profit,
          cost: c['cost'],
          revenue: c['revenue'],
          growth_days: c['growth_days'],
          move_instruction: c['move_instruction']
        }
      end
    end
    # "2025-01-01T00:00:00" → "2025-01-01" に正規化
    def normalize_date(value)
      return nil unless value

      Date.parse(value.to_s).to_s
    rescue ArgumentError
      value.to_s
    end
  end
end
