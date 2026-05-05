# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractor < Domain::Crop::Ports::CropUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
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
          attrs[:variety] = input_dto.variety if !input_dto.variety.nil?
          attrs[:area_per_unit] = input_dto.area_per_unit if !input_dto.area_per_unit.nil?
          attrs[:revenue_per_area] = input_dto.revenue_per_area if !input_dto.revenue_per_area.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          attrs[:groups] = input_dto.groups if !input_dto.groups.nil?
          attrs[:is_reference] = input_dto.is_reference if !input_dto.is_reference.nil?
          attrs[:crop_stages_attributes] = input_dto.crop_stages_attributes if Domain::Shared::ValidationHelpers.present?(input_dto.crop_stages_attributes)

          crop_entity = @gateway.update_for_user(user, input_dto.crop_id, attrs)

          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
