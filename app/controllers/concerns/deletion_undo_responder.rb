# frozen_string_literal: true

module DeletionUndoResponder
  extend ActiveSupport::Concern

  private

  def render_deletion_undo_response(event, fallback_location:, status: :ok)
    raise DeletionUndo::Error, 'DeletionUndoEvent must be present' unless event

    if event.undo_token.blank?
      Rails.logger.error("[DeletionUndo] Missing undo_token for #{event.resource_type}##{event.resource_id}")
      raise DeletionUndo::Error, 'Undo token could not be generated'
    end

    respond_to do |format|
      format.json do
        resource_dom_id = resource_dom_id_for(event)
        render json: {
          undo_token: event.undo_token,
          undo_deadline: event.metadata['undo_deadline'],
          toast_message: event.toast_message,
          undo_path: undo_deletion_path(undo_token: event.undo_token),
          auto_hide_after: event.auto_hide_after,
          resource: event.metadata['resource_label'],
          redirect_path: fallback_location,
          resource_dom_id: resource_dom_id
        }, status: status
      end

      format.html do
        redirect_back fallback_location: fallback_location,
                      notice: I18n.t('deletion_undo.redirect_notice', resource: event.metadata['resource_label'])
      end
    end
  end

  def resource_dom_id_for(event)
    stored_dom_id = event.metadata['resource_dom_id']
    return stored_dom_id if stored_dom_id.present?

    [
      event.resource_type.demodulize.underscore,
      event.resource_id
    ].join("_")
  end

  def render_deletion_failure(message:, fallback_location:, status: :unprocessable_entity)
    respond_to do |format|
      format.json do
        render json: { error: message }, status: status
      end
      format.html do
        redirect_back fallback_location: fallback_location, alert: message
      end
    end
  end
end

