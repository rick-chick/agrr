# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestDestroyInteractor < Domain::Pest::Ports::PestDestroyInputPort
        def initialize(output_port:, user_id:, translator:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(pest_id)
          user = @user_lookup.find(@user_id)
          result = @gateway.soft_destroy_with_undo(
            user: user,
            pest_id: pest_id,
            auto_hide_after: 5000,
            translator: @translator
          )
          if result[:success]
            dto = Domain::Pest::Dtos::PestDestroyOutputDto.new(undo: result[:undo_entity])
            @output_port.on_success(dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Pest not found"))
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("pests.flash.no_permission")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
