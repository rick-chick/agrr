# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDestroyInteractor < Domain::Pesticide::Ports::PesticideDestroyInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          result = @gateway.soft_destroy_with_undo(
            user: user,
            pesticide_id: pesticide_id,
            auto_hide_after: 5000,
            translator: @translator
          )
          if result[:success]
            dto = Domain::Pesticide::Dtos::PesticideDestroyOutputDto.new(undo: result[:undo_entity])
            @output_port.on_success(dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
