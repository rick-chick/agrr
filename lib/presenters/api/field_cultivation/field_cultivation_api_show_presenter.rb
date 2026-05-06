# frozen_string_literal: true

module Presenters
  module Api
    module FieldCultivation
      class FieldCultivationApiShowPresenter < Domain::FieldCultivation::Ports::FieldCultivationApiShowOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          @view.render_response(
            json: {
              id: dto.id,
              field_name: dto.field_name,
              crop_name: dto.crop_name,
              area: dto.area,
              start_date: dto.start_date,
              completion_date: dto.completion_date,
              cultivation_days: dto.cultivation_days,
              estimated_cost: dto.estimated_cost,
              gdd: dto.gdd,
              status: dto.status
            },
            status: :ok
          )
        end

        def on_failure(err)
          msg = err.respond_to?(:message) ? err.message : err.to_s
          @view.render_response(json: { error: msg }, status: :not_found)
        end
      end
    end
  end
end
