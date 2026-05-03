# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractor < Domain::Farm::Ports::FarmUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:region] = input_dto.region if Domain::Shared::ValidationHelpers.present?(input_dto.region)
          attrs[:latitude] = input_dto.latitude if !input_dto.latitude.nil?
          attrs[:longitude] = input_dto.longitude if !input_dto.longitude.nil?

          farm_entity = @gateway.update_for_user(user, input_dto.farm_id, attrs)

          @output_port.on_success(farm_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
