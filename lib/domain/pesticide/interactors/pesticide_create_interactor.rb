# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideCreateInteractor < Domain::Pesticide::Ports::PesticideCreateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          pesticide_entity = @gateway.create_for_user(user, {
            name: input_dto.name,
            active_ingredient: input_dto.active_ingredient,
            description: input_dto.description,
            crop_id: input_dto.crop_id,
            pest_id: input_dto.pest_id,
            region: input_dto.region,
            is_reference: input_dto.is_reference
          }.compact)

          @output_port.on_success(pesticide_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
