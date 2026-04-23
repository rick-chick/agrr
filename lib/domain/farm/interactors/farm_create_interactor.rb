# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor < Domain::Farm::Ports::FarmCreateInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          farm_model = @gateway.create_for_user(user, {
            name: input_dto.name,
            region: input_dto.region,
            latitude: input_dto.latitude,
            longitude: input_dto.longitude
          })

          farm_entity = Domain::Farm::Entities::FarmEntity.from_model(farm_model)
          @output_port.on_success(farm_entity)
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
