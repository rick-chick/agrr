# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDetailInteractor < Domain::Farm::Ports::FarmDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(farm_id)
          user = User.find(@user_id)
          farm_model = Domain::Shared::Policies::FarmPolicy.find_visible!(::Farm, user, farm_id)
          farm_detail_dto = Domain::Farm::Dtos::FarmDetailOutputDto.from_models(farm_model, farm_model.fields)
          @output_port.on_success(farm_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end