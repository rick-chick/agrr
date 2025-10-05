# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :user

  validates :session_id, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Clean up expired sessions
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  # Generate secure session ID
  def self.generate_session_id
    SecureRandom.urlsafe_base64(32)
  end

  # Validate session ID format
  def self.valid_session_id?(session_id)
    return false unless session_id.is_a?(String)
    return false unless session_id.length == 43 # Base64 32-byte encoding length
    return false unless session_id.match?(/\A[A-Za-z0-9_-]+\z/)
    true
  end

  # Create new session for user
  def self.create_for_user(user)
    create!(
      session_id: generate_session_id,
      user: user,
      expires_at: 2.weeks.from_now
    )
  end

  # Check if session is expired
  def expired?
    expires_at <= Time.current
  end

  # Extend session expiration
  def extend_expiration
    update!(expires_at: 2.weeks.from_now)
  end

  # Clean up expired sessions
  def self.cleanup_expired
    expired.destroy_all
  end
end
