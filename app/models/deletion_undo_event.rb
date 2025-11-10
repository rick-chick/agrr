# frozen_string_literal: true

class DeletionUndoEvent < ApplicationRecord
  DEFAULT_AUTO_HIDE_SECONDS = 5

  belongs_to :deleted_by, class_name: 'User', optional: true

  enum :state, {
    scheduled: 'scheduled',
    restored: 'restored',
    expired: 'expired',
    failed: 'failed'
  }

  validates :resource_type, :resource_id, :snapshot, :expires_at, :state, presence: true

  before_validation :ensure_state, on: :create
  before_validation :ensure_expires_at, on: :create
  before_validation :ensure_auto_hide_metadata, on: :create
  before_validation :ensure_id, on: :create

  scope :active, -> { scheduled.where('expires_at > ?', Time.current) }

  def undo_token
    id
  end

  def expired?
    Time.current >= expires_at
  end

  def expire_if_needed!
    return unless expired? && scheduled?

    update_columns(
      state: DeletionUndoEvent.states[:expired],
      finalized_at: Time.current,
      updated_at: Time.current
    )
  end

  def mark_restored!
    update!(
      state: :restored,
      restored_at: Time.current,
      finalized_at: Time.current
    )
  end

  def mark_failed!(error_message: nil)
    metadata['error'] = error_message if error_message.present?
    update!(
      state: :failed,
      finalized_at: Time.current,
      metadata: metadata
    )
  end

  def toast_message
    metadata['toast_message']
  end

  def auto_hide_after
    metadata['auto_hide_after'] || DEFAULT_AUTO_HIDE_SECONDS
  end

  private

  def ensure_state
    self.state ||= 'scheduled'
  end

  def ensure_expires_at
    self.expires_at ||= Time.current + DeletionUndo::Manager.default_ttl
  end

  def ensure_auto_hide_metadata
    metadata['auto_hide_after'] ||= DEFAULT_AUTO_HIDE_SECONDS
  end

  def ensure_id
    self.id = SecureRandom.uuid if id.blank?
  end
end

