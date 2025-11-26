# frozen_string_literal: true

# Pesticide（農薬）モデル
#
# Attributes:
#   id: 農薬ID（主キー）
#   name: 農薬名（必須）
#   active_ingredient: 有効成分名
#   description: 説明文
#   is_reference: 参照データフラグ
#   user_id: 所有ユーザー（参照農薬の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用農薬マスタ
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の農薬
#     - user_idが設定される（ユーザー所有）
class Pesticide < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :crop
  belongs_to :pest

  has_one :pesticide_usage_constraint, dependent: :destroy
  has_one :pesticide_application_detail, dependent: :destroy

  accepts_nested_attributes_for :pesticide_usage_constraint, allow_destroy: true
  accepts_nested_attributes_for :pesticide_application_detail, allow_destroy: true

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :crop, presence: true
  validates :pest, presence: true
  validates :source_pesticide_id, uniqueness: { scope: :user_id }, allow_nil: true

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の pesticide 出力形式からPesticideを作成または更新
  # @param pesticide_data [Hash] agrr pesticide コマンドの個別農薬データ
  # @param crop_id [Integer] 作物ID（必須）
  # @param pest_id [Integer] 害虫ID（必須）
  # @param is_reference [Boolean] 参照データかどうか（デフォルト: true）
  # @return [Pesticide] 作成または更新されたPesticide
  # @raise [StandardError] 必須データが欠損している場合
  def self.from_agrr_output(pesticide_data:, crop_id:, pest_id:, is_reference: true)
    # pesticide_idが指定されている場合は、idとして解釈して既存レコードを検索
    # 指定されていない場合は新規作成
    pesticide = if pesticide_data['pesticide_id'].present?
      find_by(id: pesticide_data['pesticide_id'], crop_id: crop_id, pest_id: pest_id) ||
      new(crop_id: crop_id, pest_id: pest_id)
    else
      new(crop_id: crop_id, pest_id: pest_id)
    end

    unless crop_id
      raise StandardError, "crop_id is required"
    end

    unless pest_id
      raise StandardError, "pest_id is required"
    end
    pesticide.assign_attributes(
      crop_id: crop_id,
      pest_id: pest_id,
      name: pesticide_data['name'],
      active_ingredient: pesticide_data['active_ingredient'],
      description: pesticide_data['description'],
      is_reference: is_reference
    )
    # 参照データとして取り込む場合はシステム所有（user_idを必ずnilにする）
    pesticide.user_id = nil if is_reference
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
  # @note crop_idとpest_idも含める（Entityとの整合性のため）
  def to_agrr_output
    {
      'pesticide_id' => id.to_s,  # idをpesticide_idとして出力（agrr CLIとの互換性のため）
      'crop_id' => crop_id.to_s,  # agrr CLIは文字列を期待する可能性があるためto_s
      'pest_id' => pest_id.to_s,  # agrr CLIは文字列を期待する可能性があるためto_s
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

  # 参照農薬は user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end

