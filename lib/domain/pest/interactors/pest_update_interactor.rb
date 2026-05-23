# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestUpdateInteractor < Domain::Pest::Ports::PestUpdateInputPort
        include PestMasterFormFailureBuilder

        def initialize(output_port:, user_id:, gateway:, logger:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PestPolicy.record_access_filter(user)
          current = @gateway.find_authorized_for_edit(user, input_dto.pest_id, access_filter: access_filter)

          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:name_scientific] = input_dto.name_scientific if !input_dto.name_scientific.nil?
          attrs[:family] = input_dto.family if !input_dto.family.nil?
          attrs[:order] = input_dto.order if !input_dto.order.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:occurrence_season] = input_dto.occurrence_season if !input_dto.occurrence_season.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?

          # Nested attributes
          attrs[:pest_temperature_profile_attributes] = input_dto.pest_temperature_profile_attributes if input_dto.pest_temperature_profile_attributes
          attrs[:pest_thermal_requirement_attributes] = input_dto.pest_thermal_requirement_attributes if input_dto.pest_thermal_requirement_attributes
          attrs[:pest_control_methods_attributes] = input_dto.pest_control_methods_attributes if input_dto.pest_control_methods_attributes

          # is_referenceのチェック
          if Domain::Shared.present?(input_dto.is_reference)
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: is_reference, current: current.reference?)
              raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("pests.flash.reference_flag_admin_only"))
            end
            attrs[:is_reference] = is_reference
          end

          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(
            user,
            { is_reference: current.reference? },
            attrs
          )
          pest_entity = @gateway.update_for_user(user, input_dto.pest_id, normalized, access_filter: access_filter)

          unless input_dto.crop_ids.nil?
            @gateway.update_pest_crop_associations(pest_id: pest_entity.id, crop_ids: input_dto.crop_ids, user: user)
          end

          @logger.info "PestUpdateInteractor: on_success called with pest_entity.id = #{pest_entity.id}"
          @output_port.on_success(pest_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(form_failure_or_error(user, input_dto, e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(form_failure_or_error(user, input_dto, e.message))
        end

        private

        def form_failure_or_error(user, input_dto, message)
          if message == @translator.t("pests.flash.reference_flag_admin_only")
            Domain::Pest::Dtos::PestReferenceFlagChangeDenied.new(
              message: message,
              pest_id: input_dto.pest_id
            )
          else
            pest_master_form_failure_for(user, input_dto, message: message)
          end
        end
      end
    end
  end
end
