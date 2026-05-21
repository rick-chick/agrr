# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class ReferenceFarmsApiPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(farms)
          payload = farms.map { |farm| { id: farm.id, name: farm.name, latitude: farm.latitude, longitude: farm.longitude, region: farm.region } }
          @view.render json: payload
        end

        def on_failure(error_dto)
          @view.render json: { error: error_dto.message }, status: :internal_server_error
        end
      end
    end
  end
end
