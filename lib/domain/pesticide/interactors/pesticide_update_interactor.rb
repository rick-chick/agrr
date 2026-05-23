# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideUpdateInteractor < Domain::Pesticide::Ports::PesticideUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          current = @gateway.find_by_id(input_dto.pesticide_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)

          unless input_dto.is_reference.nil?
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference)
            requested = false if requested.nil?
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: requested, current: !!current.is_reference)
              return @output_port.on_failure(
                Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(
                  message: @translator.t("pesticides.flash.reference_flag_admin_only"),
                  resource_id: input_dto.pesticide_id
                )
              )
            end
          end

          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:active_ingredient] = input_dto.active_ingredient if !input_dto.active_ingredient.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:crop_id] = input_dto.crop_id if !input_dto.crop_id.nil?
          attrs[:pest_id] = input_dto.pest_id if !input_dto.pest_id.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          attrs[:is_reference] = input_dto.is_reference if !input_dto.is_reference.nil?

          normalized = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_update(
            user,
            { is_reference: !!current.is_reference },
            attrs
          )
          pesticide_entity = @gateway.update_for_user(user, input_dto.pesticide_id, normalized)

          @output_port.on_success(pesticide_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          user_b = @user_lookup.find(@user_id)
          bundle = PesticideMasterFormBundleAssembler.new(gateway: @gateway).bundle_after_update_merge(
            user: user_b,
            pesticide_id: input_dto.pesticide_id,
            assign_attributes: input_dto.assign_attributes_for_form || {}
          )
          @output_port.on_failure(Domain::Pesticide::Dtos::PesticideMasterFormFailure.new(message: e.message, bundle: bundle))
        end
      end
    end
  end
end
