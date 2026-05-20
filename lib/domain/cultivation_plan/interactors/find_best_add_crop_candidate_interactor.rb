# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # add_crop 候補探索（Concern にあった主導線のオーケストレーション）。
      # 永続化・HTTP・寛い rescue は注入側（CompositionRoot の Proc）に閉じる。
      class FindBestAddCropCandidateInteractor
        def initialize(
          logger:,
          today:,
          plan_loader:,
          allocation_configs:,
          weather_for_candidates:,
          candidates_invoker:
        )
          @logger = logger
          @today = today
          @plan_loader = plan_loader
          @allocation_configs = allocation_configs
          @weather_for_candidates = weather_for_candidates
          @candidates_invoker = candidates_invoker
        end

        # @param ui_filter_context [Hash] ログ用（params 由来。空可）
        def call(cultivation_plan:, crop:, field_id:, display_range:, ui_filter_context: {})
          plan = @plan_loader.call(cultivation_plan)
          configs = @allocation_configs.call(plan)
          current_allocation = configs.fetch(:current_allocation)
          fields = configs.fetch(:fields)
          crops = configs.fetch(:crops)
          interaction_rules = configs.fetch(:interaction_rules)

          display_start_date = display_range[:start_date]
          display_end_date = display_range[:end_date]
          fallback_start = plan.calculated_planning_start_date || @today.call
          candidates_start = display_start_date || fallback_start
          base_end =
            plan.calculated_planning_end_date ||
            Date.new(candidates_start.year + 2, 12, 31)
          candidates_end = [ base_end, display_end_date ].compact.max
          target_end_date = display_end_date || candidates_end

          log_candidate_window(
            display_start_date: display_start_date,
            display_end_date: display_end_date,
            ui_filter_context: ui_filter_context,
            candidates_start: candidates_start,
            candidates_end: candidates_end,
            target_end_date: target_end_date
          )

          farm = plan.farm
          weather_location = farm&.weather_location
          unless weather_location
            @logger.error "❌ [Candidates] No weather location found"
            return nil
          end

          weather_data = @weather_for_candidates.call(
            weather_location: weather_location,
            farm: farm,
            cultivation_plan: plan,
            target_end_date: target_end_date
          )
          return nil unless weather_data

          @logger.info "📅 [Candidates] Planning period: #{candidates_start} ~ #{candidates_end} (weather_target_end=#{target_end_date})"

          candidates = @candidates_invoker.call(
            current_allocation: current_allocation,
            fields: fields,
            crops: crops,
            crop: crop,
            weather_data: weather_data,
            planning_start: candidates_start,
            planning_end: candidates_end,
            interaction_rules: interaction_rules
          )

          return select_best_candidate(candidates, field_id) unless candidates.empty?

          @logger.warn "⚠️ [Candidates] No candidates found for target_end_date=#{target_end_date}"
          nil
        end

        private

        def log_candidate_window(display_start_date:, display_end_date:, ui_filter_context:,
          candidates_start:, candidates_end:, target_end_date:)
          if display_start_date || display_end_date
            @logger.info "📅 [Candidates] UI表示範囲: start=#{display_start_date || 'N/A'} end=#{display_end_date || 'N/A'}"
          else
            @logger.info "📅 [Candidates] UI表示範囲: not provided"
          end
          filters = Domain::Shared::ValidationHelpers.present?(ui_filter_context) ? ui_filter_context : "none"
          @logger.info "📋 [Candidates] UI filters: #{filters}"
          @logger.info "📅 [Candidates] Candidate window: start=#{candidates_start} (UI start=#{display_start_date || 'N/A'}) end=#{candidates_end} target_end_date=#{target_end_date}"
        end

        def select_best_candidate(candidates, preferred_field_id)
          preferred_field_id = preferred_field_id.to_i if Domain::Shared::ValidationHelpers.present?(preferred_field_id)

          today = @today.call
          future_candidates = candidates.select do |c|
            candidate_date = Date.parse(c[:start_date].to_s)
            candidate_date >= today
          rescue ArgumentError
            false
          end

          @logger.info "🔍 [Candidates] Total: #{candidates.length}, Future: #{future_candidates.length} (filtered past dates before #{today})"

          return nil if future_candidates.empty?

          field_candidates = if preferred_field_id
            future_candidates.select { |c| c[:field_id].to_i == preferred_field_id }
          else
            []
          end

          pool = !field_candidates.empty? ? field_candidates : future_candidates
          pool.max_by { |c| c[:profit].to_f }
        end
      end
    end
  end
end
