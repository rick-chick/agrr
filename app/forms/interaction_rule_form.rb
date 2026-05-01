# frozen_string_literal: true

# InteractionRule 用 Form Object。
#
# 役割:
# - HTML View / form_with から AR (`::InteractionRule`) を取り除く受け皿。
# - Domain Entity (`Domain::InteractionRule::Entities::InteractionRuleEntity`) と
#   生 params の双方からインスタンス化できる。
# - エラー表示は Interactor の失敗結果から `errors_from` で流し込む。
class InteractionRuleForm < ApplicationForm
  attribute :rule_type, :string
  attribute :source_group, :string
  attribute :target_group, :string
  attribute :impact_ratio, :float
  attribute :is_directional, :boolean
  attribute :description, :string
  attribute :region, :string
  attribute :is_reference, :boolean

  validates :rule_type, presence: true
  validates :source_group, presence: true
  validates :target_group, presence: true
  validates :impact_ratio, presence: true,
                           numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :region, inclusion: { in: %w[jp us in] }, allow_blank: true

  # Entity からフォームを構築する。Entity が `to_hash` を持つ前提。
  def self.from_entity(entity, **extra)
    return new(**extra) if entity.nil?

    attrs = entity.to_hash.symbolize_keys.slice(
      :id, :rule_type, :source_group, :target_group, :impact_ratio,
      :is_directional, :description, :region, :is_reference
    )
    new(**attrs, **extra)
  end

  # form params からフォームを構築する。Strong Parameters の責務は Controller。
  def self.from_params(params, **extra)
    return new(**extra) if params.nil?

    h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    new(**h.symbolize_keys, **extra)
  end
end
