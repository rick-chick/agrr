# frozen_string_literal: true

class Field < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  # Note: FieldCultivationは cultivation_plan_field を通じて関連付けられています

  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :farm_id, case_sensitive: false }
  validates :area, numericality: { greater_than: 0 }, allow_nil: true
  validates :daily_fixed_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # == Scopes ==============================================================
  scope :by_user, ->(user) { where(user: user) }
  scope :by_farm, ->(farm) { where(farm: farm) }
  scope :by_region, ->(region) { where(region: region) }
  scope :anonymous, -> { where(user_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # == Instance Methods ====================================================
  
  def display_name
    name.presence || "##{id}"
  end

  # Export field configuration for agrr CLI
  def to_agrr_config
    {
      field_id: id.to_s,
      name: name,
      area: area,
      daily_fixed_cost: daily_fixed_cost
    }
  end
end
