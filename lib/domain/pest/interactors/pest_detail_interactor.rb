# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestDetailInteractor < Domain::Pest::Ports::PestDetailInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(pest_id)
          user = @user_lookup.find(@user_id)
          pest_model = @gateway.find_authorized_for_view(user, pest_id)
          pest_entity = Domain::Pest::Entities::PestEntity.from_model(pest_model)
          dto = Domain::Pest::Dtos::PestDetailOutputDto.new(pest: pest_entity, pest_model: pest_model)
          @output_port.on_success(dto)
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("pests.flash.not_found")))
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("pests.flash.no_permission")))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
