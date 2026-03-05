# frozen_string_literal: true

class DeletionUndosController < ApplicationController
  skip_before_action :authenticate_user!, only: :create, if: -> { Rails.env.test? }
  # Angular からの JSON POST は別オリジン（dev: localhost:4200→3000）のため CSRF トークンを送れない。
  # 復元は undo_token（秘密・一時）とセッション認証で保護されている。
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  def create
    input_dto = Domain::DeletionUndo::Dtos::DeletionUndoRestoreInputDto.new(
      undo_token: params.require(:undo_token)
    )

    respond_to do |format|
      format.json do
        execute_restore_use_case(input_dto, Presenters::Api::DeletionUndo::DeletionUndoRestorePresenter)
      end

      format.html do
        execute_restore_use_case(input_dto, Presenters::Html::DeletionUndo::DeletionUndoRestoreHtmlPresenter)
      end
    end
  end

  # DeletionUndoRestorePresenter (format.json) が参照する View インターフェース
  def render_response(json:, status:)
    render json: json, status: status
  end

  private

  def execute_restore_use_case(input_dto, presenter_class)
    presenter = presenter_class.new(view: self)
    interactor = Domain::DeletionUndo::Interactors::DeletionUndoRestoreInteractor.new(
      output_port: presenter,
      gateway: deletion_undo_gateway
    )
    interactor.call(input_dto)
  end

  def deletion_undo_gateway
    @deletion_undo_gateway ||= Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
  end
end

