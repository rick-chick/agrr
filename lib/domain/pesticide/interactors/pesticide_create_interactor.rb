# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideCreateInteractor < Domain::Pesticide::Ports::PesticideCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          pesticide_model = Domain::Shared::Policies::PesticidePolicy.build_for_create(::Pesticide, user, {
            name: input_dto.name,
            active_ingredient: input_dto.active_ingredient,
            description: input_dto.description,
            crop_id: input_dto.crop_id,
            pest_id: input_dto.pest_id,
            region: input_dto.region
          }.compact)
          raise StandardError, pesticide_model.errors.full_messages.join(', ') unless pesticide_model.save

          pesticide_entity = Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide_model)
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
