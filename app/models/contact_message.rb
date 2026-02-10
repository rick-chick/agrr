class ContactMessage < ApplicationRecord
  STATUSES = %w[queued sent failed].freeze

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :name, length: { maximum: 255 }, allow_nil: true
  validates :source, length: { maximum: 255 }, allow_nil: true
  validates :subject, length: { maximum: 255 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
end

