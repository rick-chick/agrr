# frozen_string_literal: true

class DeletionUndosController < ApplicationController
  skip_before_action :authenticate_user!, only: :create, if: -> { Rails.env.test? }
  protect_from_forgery with: :exception

  def create
    undo_token = params.require(:undo_token)
    event = DeletionUndo::Manager.restore!(undo_token: undo_token)

    respond_to do |format|
      format.json do
        render json: {
          status: 'restored',
          undo_token: event.undo_token
        }, status: :ok
      end

      format.html do
        redirect_back fallback_location: root_path,
                      notice: I18n.t('deletion_undo.restored')
      end
    end
  rescue DeletionUndo::ExpiredTokenError
    render_undo_error('deletion_undo.expired')
  rescue DeletionUndo::RestoreConflictError => e
    render_undo_error('deletion_undo.restore_failed', error: e.message)
  rescue ActiveRecord::RecordNotFound
    render_undo_error('deletion_undo.not_found')
  end

  private

  def render_undo_error(key, error: nil)
    message = I18n.t(key, default: 'Undo failed')
    respond_to do |format|
      format.json { render json: { status: 'error', error: message }, status: :unprocessable_entity }
      format.html { redirect_back fallback_location: root_path, alert: message }
    end
  end
end

