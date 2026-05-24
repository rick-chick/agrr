# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      # 参照作物の各ステージ required_gdd 合算が大きすぎる場合、比率を保ちつつ optimize period 用に上限へ収める。
      class EntryScheduleStageGddScaler
        DEFAULT_MAX_TOTAL_GDD_FOR_OPTIMIZE = 2_000.0

        # @param requirement_hash [Hash] Crop#to_agrr_requirement 相当（"stage_requirements" キー）
        # @param max_total_gdd [Float, nil]
        # @param env [#[]] ENV 相当（テストでは固定 Hash を渡す）
        # @return [Hash] スケール済みの deep copy
        def self.call(requirement_hash, max_total_gdd: nil, env: ENV)
          max_total = (max_total_gdd || env["ENTRY_SCHEDULE_MAX_TOTAL_GDD"].presence&.to_f)
          max_total = DEFAULT_MAX_TOTAL_GDD_FOR_OPTIMIZE if max_total.nil? || max_total <= 0

          req = Domain::Shared.deep_dup(requirement_hash)
          stages = req["stage_requirements"]
          return req unless stages.is_a?(Array)

          sum = stages.sum { |s| s.dig("thermal", "required_gdd").to_f }
          return req if sum <= 0.0 || sum <= max_total

          factor = max_total / sum
          stages.each do |stage|
            next unless stage.is_a?(Hash) && stage["thermal"].is_a?(Hash)

            gdd = stage["thermal"]["required_gdd"].to_f
            stage["thermal"]["required_gdd"] = (gdd * factor).round(2)
          end
          req
        end
      end
    end
  end
end
