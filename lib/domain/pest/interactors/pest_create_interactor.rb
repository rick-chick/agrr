# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestCreateInteractor < Domain::Pest::Ports::PestCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)

          # is_referenceをbooleanに変換
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_assignment_allowed?(user, is_reference: is_reference)
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("pests.flash.reference_only_admin"))
          end

          attrs = {
            name: input_dto.name,
            name_scientific: input_dto.name_scientific,
            family: input_dto.family,
            order: input_dto.order,
            description: input_dto.description,
            occurrence_season: input_dto.occurrence_season,
            region: input_dto.region,
            is_reference: is_reference
          }

          # Nested attributes
          attrs[:pest_temperature_profile_attributes] = input_dto.pest_temperature_profile_attributes if input_dto.pest_temperature_profile_attributes
          attrs[:pest_thermal_requirement_attributes] = input_dto.pest_thermal_requirement_attributes if input_dto.pest_thermal_requirement_attributes
          attrs[:pest_control_methods_attributes] = input_dto.pest_control_methods_attributes if input_dto.pest_control_methods_attributes

          attrs = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(user, attrs)
          pest_entity = @gateway.create_for_user(user, attrs)

          if Domain::Shared.present?(input_dto.crop_ids)
            @gateway.associate_crops_with_pest_id(pest_id: pest_entity.id, crop_ids: input_dto.crop_ids, user: user)
          end

          @output_port.on_success(pest_entity)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
