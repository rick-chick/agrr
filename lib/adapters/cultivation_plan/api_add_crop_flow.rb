# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # add_crop の永続化・候補探索・adjust を1系統にまとめ、失敗はシンボル kind で返す。
    class ApiAddCropFlow
      def initialize(host_controller)
        @host = host_controller
      end

      # @return [Hash] keys: :kind, and kind ごとの追加キー
      def full_run(plan_loader:, crop_id:, field_id:, display_range:)
        cultivation_plan =
          begin
            plan_loader.load
          rescue ActiveRecord::RecordNotFound
            return { kind: :not_found }
          end

        @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

        crop_entity = @host.send(:get_crop_for_add_crop, crop_id)
        unless crop_entity
          return { kind: :crop_not_found }
        end

        crop = ::Crop.find(crop_entity.id)

        plan_crop = cultivation_plan.cultivation_plan_crops.create!(
          crop: crop,
          name: crop.name,
          variety: crop.variety,
          area_per_unit: crop.area_per_unit,
          revenue_per_area: crop.revenue_per_area
        )

        best_candidate =
          begin
            @host.send(:find_best_candidate_for_crop, crop, field_id, display_range: display_range)
          rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
                 Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
            plan_crop.destroy! if plan_crop.persisted?
            @host.logger.warn "⚠️ [Add Crop] Prediction data incomplete: #{e.message}"
            return { kind: :prediction_incomplete, technical_details: e.message }
          end

        unless best_candidate
          plan_crop.destroy!
          return { kind: :no_candidates }
        end

        @host.logger.info "🌱 [Add Crop] Best candidate: field=#{best_candidate[:field_id]}, start=#{best_candidate[:start_date]}"

        moves = [
          {
            allocation_id: nil,
            action: "add",
            crop_id: crop.id.to_s,
            to_field_id: best_candidate[:field_id] || field_id,
            to_start_date: best_candidate[:start_date],
            to_area: crop.area_per_unit,
            variety: crop.variety
          }
        ]

        result = @host.adjust_with_db_weather(cultivation_plan, moves)

        if result[:success]
          {
            kind: :success,
            plan_crop_id: plan_crop.id,
            plan_crop_display_name: plan_crop.display_name
          }
        else
          { kind: :adjust_failed, adjust_payload: result }
        end
      rescue ActiveRecord::RecordNotFound => e
        @host.logger.error "❌ [Add Crop] Not found: #{e.message}"
        { kind: :not_found }
      rescue ActiveRecord::RecordInvalid => e
        @host.logger.error "❌ [Add Crop] Record invalid: #{e.message}"
        { kind: :record_invalid, message: e.message }
      rescue StandardError => e
        @host.logger.error "❌ [Add Crop] Error: #{e.message}"
        @host.logger.error e.backtrace.join("\n")
        { kind: :unexpected, message: e.message }
      end
    end
  end
end
