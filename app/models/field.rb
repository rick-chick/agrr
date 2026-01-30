# frozen_string_literal: true

class Field < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  # Note: FieldCultivationは cultivation_plan_field を通じて関連付けられています

  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: [:user_id, :farm_id], case_sensitive: false }
  validates :area, numericality: { greater_than: 0 }, allow_nil: true
  validates :daily_fixed_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # == Callbacks ===========================================================
  after_create_commit :broadcast_field_created
  after_update_commit :broadcast_field_updated
  after_destroy_commit :broadcast_field_destroyed

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

  # ActiveRecordのdom_idヘルパーを使えるようにする
  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end

  private

  # ActionCableで圃場作成をブロードキャスト
  def broadcast_field_created
    return if Rails.env.test?
    Rails.logger.info "🔔 [Field##{id}] Broadcasting field created"
    
    # 圃場一覧画面を更新
    broadcast_prepend_to(
      farm,
      target: "fields",
      partial: "fields/field_card",
      locals: { field: self, farm: farm }
    )
    
    # 農場の圃場数も更新（直接ブロードキャスト）
    farm.broadcast_replace_to(
      farm,
      target: dom_id(farm),
      partial: "farms/farm_card_wrapper",
      locals: { farm: farm }
    )
  end

  # ActionCableで圃場更新をブロードキャスト
  def broadcast_field_updated
    return if Rails.env.test?
    Rails.logger.info "🔔 [Field##{id}] Broadcasting field updated"
    
    # 圃場一覧画面を更新
    broadcast_replace_to(
      farm,
      target: dom_id(self),
      partial: "fields/field_card",
      locals: { field: self, farm: farm }
    )
  end

  # ActionCableで圃場削除をブロードキャスト
  def broadcast_field_destroyed
    return if Rails.env.test?
    Rails.logger.info "🔔 [Field##{id}] Broadcasting field destroyed"
    
    # 圃場一覧画面から削除
    broadcast_remove_to(
      farm,
      target: dom_id(self)
    )
    
    # 農場の圃場数も更新（直接ブロードキャスト）
    farm.broadcast_replace_to(
      farm,
      target: dom_id(farm),
      partial: "farms/farm_card_wrapper",
      locals: { farm: farm }
    )
  end
end
