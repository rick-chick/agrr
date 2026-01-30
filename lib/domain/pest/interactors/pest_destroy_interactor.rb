# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestDestroyInteractor < Domain::Pest::Ports::PestDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(pest_id)
          user = User.find(@user_id)
          pest_model = Domain::Shared::Policies::PestPolicy.find_editable!(::Pest, user, pest_id)
          undo_response = DeletionUndo::Manager.schedule(
            record: pest_model,
            actor: user,
            toast_message: I18n.t('pests.undo.toast', name: pest_model.name)
          )
          dto = Domain::Pest::Dtos::PestDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue ActiveRecord::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new('Pest not found'))
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(I18n.t('pests.flash.no_permission')))
        rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(I18n.t('pests.flash.cannot_delete_in_use')))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
