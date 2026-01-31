# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractor < Domain::Crop::Ports::CropUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:variety] = input_dto.variety if !input_dto.variety.nil?
          attrs[:area_per_unit] = input_dto.area_per_unit if !input_dto.area_per_unit.nil?
          attrs[:revenue_per_area] = input_dto.revenue_per_area if !input_dto.revenue_per_area.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          attrs[:groups] = input_dto.groups if !input_dto.groups.nil?
          attrs[:crop_stages_attributes] = input_dto.crop_stages_attributes if input_dto.crop_stages_attributes.present?

          crop_model = Domain::Shared::Policies::CropPolicy.find_editable!(::Crop, user, input_dto.crop_id)
          Domain::Shared::Policies::CropPolicy.apply_update!(user, crop_model, attrs)
          raise StandardError, crop_model.errors.full_messages.join(', ') if crop_model.errors.any?

          crop_entity = Domain::Crop::Entities::CropEntity.from_model(crop_model.reload)
          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
