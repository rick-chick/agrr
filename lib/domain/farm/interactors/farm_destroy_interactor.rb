# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDestroyInteractor < Domain::Farm::Ports::FarmDestroyInputPort

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

        def call(farm_id)
          user = User.find(@user_id)
          farm_model = Domain::Shared::Policies::FarmPolicy.find_editable!(::Farm, user, farm_id)

          # Note: FreeCropPlan check removed as FreeCropPlan is deprecated

          # DeletionUndo をスケジュール（これにより削除も実行される）
          undo_presenter = DeletionUndoPresenter.new
          deletion_undo_interactor = Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor.new(
            output_port: undo_presenter,
            gateway: @deletion_undo_gateway
          )

          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            record: farm_model,
            actor: user,
            toast_message: @translator.t('flash.farms.deleted', name: farm_model.name),
            auto_hide_after: 5000,
            metadata: { resource_dom_id: ActionView::RecordIdentifier.dom_id(farm_model) }
          )

          deletion_undo_interactor.call(input_dto)

          if undo_presenter.success?
            # 成功時は undo 情報を含む DTO を返す
            destroy_output_dto = Domain::Farm::Dtos::FarmDestroyOutputDto.new(undo: undo_presenter.undo_entity, farm_name: farm_model.name)
            @output_port.on_success(destroy_output_dto)
          else
            # エラー時は失敗として扱う
            @output_port.on_failure(undo_presenter.error)
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end