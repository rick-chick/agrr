# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDestroyInteractor < Domain::Pesticide::Ports::PesticideDestroyInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
        end

        def call(pesticide_id)
          user = User.find(@user_id)
          pesticide_model = Domain::Shared::Policies::PesticidePolicy.find_editable!(::Pesticide, user, pesticide_id)
          undo_response = DeletionUndo::Manager.schedule(
            record: pesticide_model,
            actor: user,
            toast_message: @translator.t('pesticides.undo.toast', name: pesticide_model.name)
          )
          dto = Domain::Pesticide::Dtos::PesticideDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
