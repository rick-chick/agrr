# frozen_string_literal: true

# Pest（害虫）モデル
#
# Attributes:
#   id: 害虫ID（主キー）
#   name: 害虫名（必須）
#   name_scientific: 学名
#   family: 科
#   order: 目
#   description: 説明
#   occurrence_season: 発生時期
#   is_reference: 参照データフラグ
#   user_id: 所有ユーザー（参照害虫の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用害虫マスタ
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の害虫
#     - user_idが設定される（ユーザー所有）
class Pest < ApplicationRecord
  belongs_to :user, optional: true
  has_one :pest_temperature_profile, dependent: :destroy
  has_one :pest_thermal_requirement, dependent: :destroy
  has_many :pest_control_methods, dependent: :destroy
  has_many :crop_pests, dependent: :destroy
  has_many :crops, through: :crop_pests

  accepts_nested_attributes_for :pest_temperature_profile, allow_destroy: true
  accepts_nested_attributes_for :pest_thermal_requirement, allow_destroy: true
  accepts_nested_attributes_for :pest_control_methods, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :user, presence: true, unless: :is_reference?

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の pest 出力形式からPestを作成または更新
  # @param pest_data [Hash] agrr pest コマンドの個別害虫データ
  # @param is_reference [Boolean] 参照データかどうか（デフォルト: true）
  # @return [Pest] 作成または更新されたPest
  # @raise [StandardError] 必須データが欠損している場合
  # @note pest_dataに'pest_id'がある場合は既存のpestを更新、ない場合は新規作成
  def self.from_agrr_output(pest_data:, is_reference: true)
    # pest_idが指定されている場合は、既存のpestを検索（後方互換性のため）
    # ただし、pest_idは文字列IDなので、nameとis_referenceで一致するものを検索
    pest = nil
    if pest_data['pest_id']
      # 既存のpestをnameで検索（pest_idからidへの移行を考慮）
      pest = find_by(name: pest_data['name'], is_reference: is_reference)
    end
    
    pest ||= new(is_reference: is_reference)
    pest.assign_attributes(
      name: pest_data['name'],
      name_scientific: pest_data['name_scientific'],
      family: pest_data['family'],
      order: pest_data['order'],
      description: pest_data['description'],
      occurrence_season: pest_data['occurrence_season'],
      is_reference: is_reference
    )
    pest.save!

    # 温度プロファイルを作成または更新
    if pest_data['temperature_profile']
      temp_profile = pest.pest_temperature_profile || pest.build_pest_temperature_profile
      temp_profile.assign_attributes(
        base_temperature: pest_data['temperature_profile']['base_temperature'],
        max_temperature: pest_data['temperature_profile']['max_temperature']
      )
      temp_profile.save!
    end

    # 熱量要件を作成または更新
    if pest_data['thermal_requirement']
      thermal_req = pest.pest_thermal_requirement || pest.build_pest_thermal_requirement
      thermal_req.assign_attributes(
        required_gdd: pest_data['thermal_requirement']['required_gdd'],
        first_generation_gdd: pest_data['thermal_requirement']['first_generation_gdd']
      )
      thermal_req.save!
    end

    # 既存の防除方法を削除
    pest.pest_control_methods.destroy_all

    # 防除方法を作成
    if pest_data['control_methods'].is_a?(Array)
      pest_data['control_methods'].each do |method_data|
        pest.pest_control_methods.create!(
          method_type: method_data['method_type'],
          method_name: method_data['method_name'],
          description: method_data['description'],
          timing_hint: method_data['timing_hint']
        )
      end
    end

    pest.reload
  end

  # agrr CLI の pest 出力形式に変換
  # @return [Hash] agrr CLI が期待する害虫データのハッシュ
  def to_agrr_output
    {
      'pest_id' => id.to_s,
      'name' => name,
      'name_scientific' => name_scientific,
      'family' => family,
      'order' => order,
      'description' => description,
      'occurrence_season' => occurrence_season,
      'temperature_profile' => pest_temperature_profile ? {
        'base_temperature' => pest_temperature_profile.base_temperature,
        'max_temperature' => pest_temperature_profile.max_temperature
      } : nil,
      'thermal_requirement' => pest_thermal_requirement ? {
        'required_gdd' => pest_thermal_requirement.required_gdd,
        'first_generation_gdd' => pest_thermal_requirement.first_generation_gdd
      } : nil,
      'control_methods' => pest_control_methods.order(:id).map do |method|
        {
          'method_type' => method.method_type,
          'method_name' => method.method_name,
          'description' => method.description,
          'timing_hint' => method.timing_hint
        }
      end
    }
  end
end

