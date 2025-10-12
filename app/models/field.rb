# frozen_string_literal: true

class Field < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  has_many :field_cultivations, dependent: :destroy
  has_many :cultivation_plans, through: :field_cultivations

  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :farm_id, case_sensitive: false }
  validates :area, numericality: { greater_than: 0 }, allow_nil: true

  # == Scopes ==============================================================
  scope :by_user, ->(user) { where(user: user) }
  scope :by_farm, ->(farm) { where(farm: farm) }
  scope :anonymous, -> { where(user_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # == Instance Methods ====================================================
  
  def display_name
    name.presence || "圃場 ##{id}"
  end
end
