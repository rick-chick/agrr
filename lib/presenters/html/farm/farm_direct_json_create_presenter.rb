# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDirectJsonCreatePresenter < Domain::Farm::Ports::FarmCreateOutputPort
        def initialize(view:, farm_model_for_json_response:)
          @view = view
          @farm_model_for_json_response = farm_model_for_json_response
        end

        def on_success(farm_entity)
          farm = @farm_model_for_json_response.call(farm_entity)
          @view.render(json: farm, status: :created)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render(json: { errors: [ msg ] }, status: :unprocessable_entity)
        end
      end
    end
  end
end
