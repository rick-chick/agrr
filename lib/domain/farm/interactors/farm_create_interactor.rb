# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor < Domain::Farm::Ports::FarmCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          farm_model = Domain::Shared::Policies::FarmPolicy.build_for_create(::Farm, user, {
            name: input_dto.name,
            region: input_dto.region,
            latitude: input_dto.latitude,
            longitude: input_dto.longitude
          })
          raise StandardError, farm_model.errors.full_messages.join(', ') unless farm_model.save

          farm_entity = Domain::Farm::Entities::FarmEntity.from_model(farm_model)
          @output_port.on_success(farm_entity)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end