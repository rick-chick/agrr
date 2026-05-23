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
          current_entity = @gateway.find_authorized_for_edit(user, input_dto.crop_id, access_filter: access_filter)

          reference_flag_msg = nil
          unless input_dto.is_reference.nil?
            reference_flag_msg = @translator.t("crops.flash.reference_flag_admin_only")
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference)
            requested = false if requested.nil?
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: requested, current: current_entity.reference?)
              raise Domain::Shared::Exceptions::RecordInvalid.new(reference_flag_msg)
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
          crop_entity = @gateway.update_for_user(user, input_dto.crop_id, normalized, access_filter: access_filter)

          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          if reference_flag_msg && e.message == reference_flag_msg
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          else
            user_b = @user_lookup.find(@user_id)
            access_filter_b = Domain::Shared::Policies::CropPolicy.record_access_filter(user_b)
            snapshot = @gateway.merge_edit_crop_params_for_master_form!(
              user: user_b,
              crop_id: input_dto.crop_id,
              attributes: input_dto.to_nested_crop_attributes_hash,
              access_filter: access_filter_b
            )
            @output_port.on_failure(Domain::Crop::Dtos::CropMasterFormFailure.new(message: e.message, master_form_snapshot: snapshot))
          end
        end
      end
    end
  end
end
