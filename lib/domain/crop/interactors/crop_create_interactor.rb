# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropCreateInteractor < Domain::Crop::Ports::CropCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          if is_reference && !user.admin?
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("crops.flash.reference_only_admin"))
          end

          attrs = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(user, {
            name: input_dto.name,
            variety: input_dto.variety,
            area_per_unit: input_dto.area_per_unit,
            revenue_per_area: input_dto.revenue_per_area,
            region: input_dto.region,
            groups: input_dto.groups || [],
            is_reference: is_reference
          })
          crop_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
