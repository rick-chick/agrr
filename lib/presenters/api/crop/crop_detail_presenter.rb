# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropDetailPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          crop_json = entity_to_json(crop_detail_dto.crop)
          @view.render_response(json: crop_json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Crop not found') ? :not_found : :unprocessable_entity
          @view.render_response(json: { error: msg }, status: status)
        end

        private

        def entity_to_json(entity)
          crop_model = entity.to_model
          stages = crop_model.crop_stages
            .includes(:temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement)
            .order(:order)
          {
            id: entity.id,
            name: entity.name,
            variety: entity.variety,
            area_per_unit: entity.area_per_unit,
            revenue_per_area: entity.revenue_per_area,
            region: entity.region,
            groups: entity.groups,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference,
            crop_stages: stages.map { |s| stage_to_json(s) }
          }
        end

        def stage_to_json(stage)
          {
            id: stage.id,
            crop_id: stage.crop_id,
            name: stage.name,
            order: stage.order,
            temperature_requirement: stage.temperature_requirement && temperature_requirement_to_json(stage.temperature_requirement),
            thermal_requirement: stage.thermal_requirement && thermal_requirement_to_json(stage.thermal_requirement),
            sunshine_requirement: stage.sunshine_requirement && sunshine_requirement_to_json(stage.sunshine_requirement),
            nutrient_requirement: stage.nutrient_requirement && nutrient_requirement_to_json(stage.nutrient_requirement)
          }.compact
        end

        def temperature_requirement_to_json(tr)
          {
            id: tr.id,
            base_temperature: tr.base_temperature,
            optimal_min: tr.optimal_min,
            optimal_max: tr.optimal_max,
            low_stress: tr.low_stress_threshold,
            high_stress: tr.high_stress_threshold
          }
        end

        def thermal_requirement_to_json(tr)
          { id: tr.id, required_gdd: tr.required_gdd }
        end

        def sunshine_requirement_to_json(sr)
          {
            id: sr.id,
            minimum_hours: sr.minimum_sunshine_hours,
            target_hours: sr.target_sunshine_hours
          }
        end

        def nutrient_requirement_to_json(nr)
          {
            id: nr.id,
            daily_uptake_n: nr.daily_uptake_n,
            daily_uptake_p: nr.daily_uptake_p,
            daily_uptake_k: nr.daily_uptake_k
          }
        end
      end
    end
  end
end
