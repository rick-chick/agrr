# frozen_string_literal: true

class FarmSize < ApplicationRecord
  # Associations
  has_many :free_crop_plans, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :area_sqm, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_display_order, -> { order(:display_order) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def display_name
    "#{name} (#{area_sqm}㎡)"
  end

  def display_area
    if area_sqm >= 10000
      "#{(area_sqm / 10000.0).round(1)}ha"
    else
      "#{area_sqm}㎡"
    end
  end
end
