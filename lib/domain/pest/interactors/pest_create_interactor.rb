# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestCreateInteractor < Domain::Pest::Ports::PestCreateInputPort
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

          # is_referenceをbooleanに変換
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          if is_reference && !user.admin?
            raise StandardError, @translator.t("pests.flash.reference_only_admin")
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

          pest_entity = @gateway.create_for_user(user, attrs)

          if Domain::Shared::ValidationHelpers.present?(input_dto.crop_ids)
            PestCropAssociationService.associate_crops_by_pest_id(pest_entity.id, input_dto.crop_ids, user: user)
          end

          @output_port.on_success(pest_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
