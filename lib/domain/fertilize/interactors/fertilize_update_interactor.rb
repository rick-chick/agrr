# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeUpdateInteractor < Domain::Fertilize::Ports::FertilizeUpdateInputPort
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

          # is_referenceをbooleanに変換してチェック
          if Domain::Shared::ValidationHelpers.present?(input_dto.is_reference)
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
            fertilize_model = @gateway.find_authorized_for_edit(user, input_dto.fertilize_id)
            if is_reference != fertilize_model.is_reference && !user.admin?
              raise StandardError, @translator.t("fertilizes.flash.reference_flag_admin_only")
            end
            attrs[:is_reference] = is_reference
          end

          attrs[:name] = input_dto.name if Domain::Shared::ValidationHelpers.present?(input_dto.name)
          attrs[:n] = input_dto.n if !input_dto.n.nil?
          attrs[:p] = input_dto.p if !input_dto.p.nil?
          attrs[:k] = input_dto.k if !input_dto.k.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:package_size] = input_dto.package_size if !input_dto.package_size.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?

          fertilize_model = @gateway.update_for_user(user, input_dto.fertilize_id, attrs)

          fertilize_entity = Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize_model)
          @output_port.on_success(fertilize_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
