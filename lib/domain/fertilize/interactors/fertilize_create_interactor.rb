# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeCreateInteractor < Domain::Fertilize::Ports::FertilizeCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)

          # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
          is_reference = ActiveModel::Type::Boolean.new.cast(input_dto.is_reference) || false
          if is_reference && !user.admin?
            raise StandardError, I18n.t('fertilizes.flash.reference_only_admin')
          end

          fertilize_model = Domain::Shared::Policies::FertilizePolicy.build_for_create(::Fertilize, user, {
            name: input_dto.name,
            n: input_dto.n,
            p: input_dto.p,
            k: input_dto.k,
            description: input_dto.description,
            package_size: input_dto.package_size,
            region: input_dto.region,
            is_reference: is_reference
          })
          raise StandardError, fertilize_model.errors.full_messages.join(', ') unless fertilize_model.save

          fertilize_entity = Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize_model)
          @output_port.on_success(fertilize_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
