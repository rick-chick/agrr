# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDestroyInteractor < Domain::Pesticide::Ports::PesticideDestroyInputPort
        # DeletionUndo の結果を扱う内部プレゼンター
        class DeletionUndoPresenter < Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort
          attr_reader :undo_entity, :error

          def initialize
            @success = false
            @undo_entity = nil
            @error = nil
          end

          def success?
            @success
          end

          def on_success(undo_entity)
            @success = true
            @undo_entity = undo_entity
          end

          def on_failure(error_dto)
            @success = false
            @error = error_dto
          end
        end

        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil, deletion_undo_gateway: nil)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @deletion_undo_gateway = deletion_undo_gateway || Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
        end

        def call(pesticide_id)
          user = User.find(@user_id)
          pesticide_model = Domain::Shared::Policies::PesticidePolicy.find_editable!(::Pesticide, user, pesticide_id)

          undo_presenter = DeletionUndoPresenter.new
          deletion_undo_interactor = Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor.new(
            output_port: undo_presenter,
            gateway: @deletion_undo_gateway
          )

          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            record: pesticide_model,
            actor: user,
            toast_message: @translator.t('pesticides.undo.toast', name: pesticide_model.name),
            auto_hide_after: 5000,
            metadata: { resource_dom_id: ActionView::RecordIdentifier.dom_id(pesticide_model) }
          )

          deletion_undo_interactor.call(input_dto)

          if undo_presenter.success?
            dto = Domain::Pesticide::Dtos::PesticideDestroyOutputDto.new(undo: undo_presenter.undo_entity)
            @output_port.on_success(dto)
          else
            @output_port.on_failure(undo_presenter.error)
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
