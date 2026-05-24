# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractor < Domain::Crop::Ports::CropUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          current_entity = @gateway.find_by_id(input_dto.crop_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current_entity)

          unless input_dto.is_reference.nil?
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference)
            requested = false if requested.nil?
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: requested, current: current_entity.reference?)
              return @output_port.on_failure(
                Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(
                  message: @translator.t("crops.flash.reference_flag_admin_only"),
                  resource_id: input_dto.crop_id
                )
              )
            end
          end

          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:variety] = input_dto.variety if !input_dto.variety.nil?
          attrs[:area_per_unit] = input_dto.area_per_unit if !input_dto.area_per_unit.nil?
          attrs[:revenue_per_area] = input_dto.revenue_per_area if !input_dto.revenue_per_area.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          attrs[:groups] = input_dto.groups if !input_dto.groups.nil?
          attrs[:is_reference] = input_dto.is_reference if !input_dto.is_reference.nil?
          attrs[:crop_stages_attributes] = input_dto.crop_stages_attributes if Domain::Shared.present?(input_dto.crop_stages_attributes)

          normalized = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_update(
            user,
            { is_reference: current_entity.reference? },
            attrs
          )
          effective_reference = normalized.fetch(:is_reference, current_entity.reference?)
          effective_user_id = normalized.fetch(:user_id, current_entity.user_id)
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_record_user_id_valid?(
            is_reference: effective_reference,
            user_id: effective_user_id
          )
            raise Domain::Shared::Exceptions::RecordInvalid.new(
              @translator.t("activerecord.errors.models.crop.attributes.user.blank")
            )
          end
          crop_entity = @gateway.update_for_user(user, input_dto.crop_id, normalized)

          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
