# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestDestroyInteractor < Domain::Pest::Ports::PestDestroyInputPort
        def initialize(output_port:, user_id:, translator:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(pest_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PestPolicy.record_access_filter(user)
          result = @gateway.soft_delete_with_undo(
            user: user,
            pest_id: pest_id,
            auto_hide_after: 5000,
            translator: @translator,
            access_filter: access_filter
          )
          if result[:success]
            dto = Domain::Pest::Dtos::PestDestroyOutput.new(undo: result[:undo_entity])
            @output_port.on_success(dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("pests.flash.not_found")))
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("pests.flash.no_permission")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
