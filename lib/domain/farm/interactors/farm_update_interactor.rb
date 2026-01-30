# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractor < Domain::Farm::Ports::FarmUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          attrs = {}
          attrs[:name] = input_dto.name if input_dto.name.present?
          attrs[:region] = input_dto.region if input_dto.region.present?
          attrs[:latitude] = input_dto.latitude if !input_dto.latitude.nil?
          attrs[:longitude] = input_dto.longitude if !input_dto.longitude.nil?

          farm_model = Domain::Shared::Policies::FarmPolicy.find_editable!(::Farm, user, input_dto.farm_id)
          Domain::Shared::Policies::FarmPolicy.apply_update!(user, farm_model, attrs)
          raise StandardError, farm_model.errors.full_messages.join(', ') if farm_model.errors.any?

          farm_entity = Domain::Farm::Entities::FarmEntity.from_model(farm_model.reload)
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