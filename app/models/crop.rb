# frozen_string_literal: true

# Crop（作物）モデル
#
# Attributes:
#   name: 作物名（必須）
#   variety: 品種名（任意）
#   is_reference: 参照作物フラグ
#   area_per_unit: 単位あたりの栽培面積（㎡）- 正の数値のみ
#   revenue_per_area: 面積あたりの収益（円/㎡）- 0以上の数値のみ
#   agrr_crop_id: agrrコマンドから取得した作物ID（更新時の識別に使用）
#   user_id: 所有ユーザー（参照作物の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用作物
#     - 管理画面で編集・削除可能
#     - 一般ユーザーも作物管理画面で参照（閲覧）可能
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の作物
#     - 作成したユーザーのみが管理可能
class Crop < ApplicationRecord
  belongs_to :user, optional: true
  has_many :crop_stages, dependent: :destroy

  accepts_nested_attributes_for :crop_stages, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :area_per_unit, numericality: { greater_than: 0, allow_nil: true }
  validates :revenue_per_area, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の crop-requirement-file フォーマットに変換
  # @return [Hash] agrr CLI が期待する作物要件のハッシュ
  # @raise [StandardError] base_temperature が未設定または0の場合
  def to_agrr_requirement
    # crop_stagesをorderでソート
    sorted_stages = crop_stages.includes(:temperature_requirement, :thermal_requirement).order(:order)
    
    # 生育ステージが未設定の場合はエラー
    if sorted_stages.empty?
      raise StandardError, "Crop '#{name}' has no growth stages. Please add growth stages with temperature and thermal requirements."
    end
    
    # 最初のステージの base_temperature を取得（全ステージで共通と仮定）
    base_temp = sorted_stages.first&.temperature_requirement&.base_temperature
    
    # base_temperature が未設定または0の場合はエラー
    if base_temp.nil? || base_temp <= 0
      raise StandardError, "Crop '#{name}' has invalid base_temperature (#{base_temp}). Please set a valid base_temperature (> 0) in the first growth stage."
    end
    
    # 全ステージの required_gdd を合計
    total_gdd = sorted_stages.sum { |stage| stage.thermal_requirement&.required_gdd || 0.0 }
    
    # stages 配列を構築
    stages_array = sorted_stages.map do |stage|
      temp_req = stage.temperature_requirement
      thermal_req = stage.thermal_requirement
      
      {
        name: stage.name,
        gdd_requirement: thermal_req&.required_gdd || 0.0,
        optimal_temp_min: temp_req&.optimal_min,
        optimal_temp_max: temp_req&.optimal_max
      }.compact # nil値を除去
    end
    
    {
      crop_name: name,
      variety: variety || "",
      base_temperature: base_temp,
      gdd_requirement: total_gdd,
      stages: stages_array
    }
  end
end


