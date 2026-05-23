# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropAiCreateApiPresenter < Domain::Crop::Ports::CropAiCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output)
          json = {
            success: output.success,
            crop_id: output.crop_id,
            crop_name: output.crop_name,
            variety: output.variety,
            area_per_unit: output.area_per_unit,
            revenue_per_area: output.revenue_per_area,
            stages_count: output.stages_count,
            message: output.message
          }
          json[:is_reference] = output.is_reference unless output.is_reference.nil?
          @view.render_response(json: json, status: output.http_status)
        end

        def on_failure(failure)
          @view.render_response(json: { error: failure.message }, status: failure.http_status)
        end
      end
    end
  end
end
