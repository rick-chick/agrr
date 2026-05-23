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
          attrs = nil
          user = @user_lookup.find(@user_id)
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_assignment_allowed?(user, is_reference: is_reference)
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("crops.flash.reference_only_admin"))
          end

          attrs = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(user, {
            name: input_dto.name,
            variety: input_dto.variety,
            area_per_unit: input_dto.area_per_unit,
            revenue_per_area: input_dto.revenue_per_area,
            region: input_dto.region,
            groups: input_dto.groups || [],
            is_reference: is_reference,
            crop_stages_attributes: input_dto.crop_stages_attributes || []
          })
          crop_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          if attrs
            snapshot = @gateway.build_new_crop_with_attributes_for_master_form(attributes: attrs)
            @output_port.on_failure(Domain::Crop::Dtos::CropMasterFormFailure.new(message: e.message, master_form_snapshot: snapshot))
          else
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          end
        end
      end
    end
  end
end
