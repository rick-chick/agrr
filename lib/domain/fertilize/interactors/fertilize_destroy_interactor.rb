# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeDestroyInteractor < Domain::Fertilize::Ports::FertilizeDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(fertilize_id)
          user = User.find(@user_id)
          fertilize_model = Domain::Shared::Policies::FertilizePolicy.find_editable!(::Fertilize, user, fertilize_id)
          undo_response = DeletionUndo::Manager.schedule(
            record: fertilize_model,
            actor: user,
            toast_message: I18n.t('fertilizes.undo.toast', name: fertilize_model.name)
          )
          dto = Domain::Fertilize::Dtos::FertilizeDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
