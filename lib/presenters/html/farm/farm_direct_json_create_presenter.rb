# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDirectJsonCreatePresenter < Domain::Farm::Ports::FarmCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_entity)
          farm = ::Farm.find(farm_entity.id)
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
