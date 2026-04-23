# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestUpdateInteractor < Domain::Pest::Ports::PestUpdateInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
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
          if Domain::Shared::ValidationHelpers.present?(input_dto.is_reference)
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
            if is_reference != @gateway.find_authorized_for_edit(user, input_dto.pest_id).is_reference && !user.admin?
              raise StandardError, @translator.t("pests.flash.reference_flag_admin_only")
            end
            attrs[:is_reference] = is_reference
          end

          pest_entity = @gateway.update_for_user(user, input_dto.pest_id, attrs)

          unless input_dto.crop_ids.nil?
            PestCropAssociationService.update_crop_associations_by_pest_id(pest_entity.id, input_dto.crop_ids, user: user)
          end

          @logger.info "PestUpdateInteractor: on_success called with pest_entity.id = #{pest_entity.id}"
          @output_port.on_success(pest_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
