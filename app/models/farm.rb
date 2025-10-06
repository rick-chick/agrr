# frozen_string_literal: true

class Farm < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :fields, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :latitude, presence: true, 
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, 
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def coordinates
    [latitude, longitude]
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def display_name
    name.presence || "農場 ##{id}"
  end
end


