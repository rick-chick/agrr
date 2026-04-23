# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideUpdateInteractor < Domain::Pesticide::Ports::PesticideUpdateInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:active_ingredient] = input_dto.active_ingredient if !input_dto.active_ingredient.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:crop_id] = input_dto.crop_id if !input_dto.crop_id.nil?
          attrs[:pest_id] = input_dto.pest_id if !input_dto.pest_id.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?

          pesticide_model = @gateway.update_for_user(user, input_dto.pesticide_id, attrs)

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
