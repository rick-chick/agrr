# frozen_string_literal: true

# Pesticide（農薬）モデル
#
# Attributes:
#   pesticide_id: 農薬ID（必須、一意）
#   name: 農薬名（必須）
#   active_ingredient: 有効成分名
#   description: 説明文
#   is_reference: 参照データフラグ
#
# is_reference フラグについて:
#   - true: システムが提供する参照用農薬マスタ
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の農薬（将来的な拡張用）
class Pesticide < ApplicationRecord
  belongs_to :crop
  belongs_to :pest

  has_one :pesticide_usage_constraint, dependent: :destroy
  has_one :pesticide_application_detail, dependent: :destroy

  accepts_nested_attributes_for :pesticide_usage_constraint, allow_destroy: true
  accepts_nested_attributes_for :pesticide_application_detail, allow_destroy: true

  validates :pesticide_id, presence: true, uniqueness: { scope: [:crop_id, :pest_id] }
  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :crop, presence: true
  validates :pest, presence: true

  scope :reference, -> { where(is_reference: true) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の pesticide 出力形式からPesticideを作成または更新
  # @param pesticide_data [Hash] agrr pesticide コマンドの個別農薬データ
  # @param is_reference [Boolean] 参照データかどうか（デフォルト: true）
  # @return [Pesticide] 作成または更新されたPesticide
  # @raise [StandardError] 必須データが欠損している場合
  def self.from_agrr_output(pesticide_data:, is_reference: true)
    unless pesticide_data['pesticide_id']
      raise StandardError, "Invalid pesticide_data: 'pesticide_id' is required"
    end

    pesticide = find_or_initialize_by(pesticide_id: pesticide_data['pesticide_id'])
    pesticide.assign_attributes(
      name: pesticide_data['name'],
      active_ingredient: pesticide_data['active_ingredient'],
      description: pesticide_data['description'],
      is_reference: is_reference
    )
    pesticide.save!

    # 使用制約を作成または更新
    if pesticide_data['usage_constraints']
      usage_constraints = pesticide.pesticide_usage_constraint || pesticide.build_pesticide_usage_constraint
      usage_constraints.assign_attributes(
        min_temperature: pesticide_data['usage_constraints']['min_temperature'],
        max_temperature: pesticide_data['usage_constraints']['max_temperature'],
        max_wind_speed_m_s: pesticide_data['usage_constraints']['max_wind_speed_m_s'],
        max_application_count: pesticide_data['usage_constraints']['max_application_count'],
        harvest_interval_days: pesticide_data['usage_constraints']['harvest_interval_days'],
        other_constraints: pesticide_data['usage_constraints']['other_constraints']
      )
      usage_constraints.save!
    end

    # 施用詳細を作成または更新
    if pesticide_data['application_details']
      application_details = pesticide.pesticide_application_detail || pesticide.build_pesticide_application_detail
      application_details.assign_attributes(
        dilution_ratio: pesticide_data['application_details']['dilution_ratio'],
        amount_per_m2: pesticide_data['application_details']['amount_per_m2'],
        amount_unit: pesticide_data['application_details']['amount_unit'],
        application_method: pesticide_data['application_details']['application_method']
      )
      application_details.save!
    end

    pesticide.reload
  end

  # agrr CLI の pesticide 出力形式に変換
  # @return [Hash] agrr CLI が期待する農薬データのハッシュ
  def to_agrr_output
    {
      'pesticide_id' => pesticide_id,
      'name' => name,
      'active_ingredient' => active_ingredient,
      'description' => description,
      'usage_constraints' => pesticide_usage_constraint ? {
        'min_temperature' => pesticide_usage_constraint.min_temperature,
        'max_temperature' => pesticide_usage_constraint.max_temperature,
        'max_wind_speed_m_s' => pesticide_usage_constraint.max_wind_speed_m_s,
        'max_application_count' => pesticide_usage_constraint.max_application_count,
        'harvest_interval_days' => pesticide_usage_constraint.harvest_interval_days,
        'other_constraints' => pesticide_usage_constraint.other_constraints
      } : nil,
      'application_details' => pesticide_application_detail ? {
        'dilution_ratio' => pesticide_application_detail.dilution_ratio,
        'amount_per_m2' => pesticide_application_detail.amount_per_m2,
        'amount_unit' => pesticide_application_detail.amount_unit,
        'application_method' => pesticide_application_detail.application_method
      } : nil
    }
  end
end

