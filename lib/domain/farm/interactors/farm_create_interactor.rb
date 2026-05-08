# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor < Domain::Farm::Ports::FarmCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          farm_entity = @gateway.create_for_user(user, {
            name: input_dto.name,
            region: input_dto.region,
            latitude: input_dto.latitude,
            longitude: input_dto.longitude
          })

          @output_port.on_success(farm_entity)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
