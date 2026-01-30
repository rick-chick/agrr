# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeUpdateInteractor < Domain::Fertilize::Ports::FertilizeUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          fertilize_model = Domain::Shared::Policies::FertilizePolicy.find_editable!(::Fertilize, user, input_dto.fertilize_id)

          attrs = {}

          # is_referenceをbooleanに変換してチェック
          if input_dto.is_reference.present?
            is_reference = ActiveModel::Type::Boolean.new.cast(input_dto.is_reference) || false
            if is_reference != fertilize_model.is_reference && !user.admin?
              raise StandardError, I18n.t('fertilizes.flash.reference_flag_admin_only')
            end
            attrs[:is_reference] = is_reference
          end

          attrs[:name] = input_dto.name if input_dto.name.present?
          attrs[:n] = input_dto.n if !input_dto.n.nil?
          attrs[:p] = input_dto.p if !input_dto.p.nil?
          attrs[:k] = input_dto.k if !input_dto.k.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:package_size] = input_dto.package_size if !input_dto.package_size.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          Domain::Shared::Policies::FertilizePolicy.apply_update!(user, fertilize_model, attrs)

          fertilize_entity = Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize_model.reload)
          @output_port.on_success(fertilize_entity)
        # rescue StandardError => e
        #   @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
