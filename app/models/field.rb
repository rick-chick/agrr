# frozen_string_literal: true

class Field < ApplicationRecord
  # Associations
  belongs_to :farm
  belongs_to :user

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :farm_id, case_sensitive: false }
  validates :latitude, presence: true, 
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, 
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :by_farm, ->(farm) { where(farm: farm) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def display_name
    name.presence || "圃場 ##{id}"
  end

  def coordinates
    [latitude, longitude]
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end
end
