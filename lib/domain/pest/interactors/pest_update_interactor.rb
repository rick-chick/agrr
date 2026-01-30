# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestUpdateInteractor < Domain::Pest::Ports::PestUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
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
          if input_dto.is_reference.present?
            is_reference = ActiveModel::Type::Boolean.new.cast(input_dto.is_reference) || false
            if is_reference != Pest.find(input_dto.pest_id).is_reference && !user.admin?
              raise StandardError, I18n.t('pests.flash.reference_flag_admin_only')
            end
            attrs[:is_reference] = is_reference
          end

          pest_model = Domain::Shared::Policies::PestPolicy.find_editable!(::Pest, user, input_dto.pest_id)
          success = Domain::Shared::Policies::PestPolicy.apply_update!(user, pest_model, attrs)
          unless success
            error_messages = []
            error_messages << pest_model.errors.full_messages
            # 関連モデルのエラーもチェック
            pest_model.pest_thermal_requirement&.errors&.full_messages&.each { |msg| error_messages << "PestThermalRequirement: #{msg}" }
            pest_model.pest_control_methods&.each { |method| method.errors.full_messages.each { |msg| error_messages << "PestControlMethod: #{msg}" } }
            Rails.logger.error "PestUpdateInteractor errors: #{error_messages.flatten.join(', ')}"
            raise StandardError, error_messages.flatten.join(', ')
          end

          unless input_dto.crop_ids.nil?
            PestCropAssociationService.update_crop_associations(pest_model, input_dto.crop_ids, user: user)
          end

          pest_entity = Domain::Pest::Entities::PestEntity.from_model(pest_model)
          Rails.logger.info "PestUpdateInteractor: on_success called with pest_entity.id = #{pest_entity.id}"
          @output_port.on_success(pest_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
