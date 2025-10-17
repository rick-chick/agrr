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
#   groups: 作物グループ（複数の文字列、JSON配列として保存）
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

  # groupsをJSON配列としてシリアライズ
  # Temporarily use coder: JSON only (without type: Array) to allow data migration
  serialize :groups, coder: JSON

  # デフォルト値を設定
  after_initialize do
    # Handle both String and Array cases during migration
    if groups.is_a?(String)
      self.groups = [groups]
    else
      self.groups ||= []
    end
  end

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :area_per_unit, numericality: { greater_than: 0, allow_nil: true }
  validates :revenue_per_area, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の crop-requirement-file フォーマットに変換（新形式）
  # @return [Hash] agrr CLI が期待する作物要件のハッシュ
  # @raise [StandardError] 必須データが未設定の場合
  def to_agrr_requirement
    # crop_stagesをorderでソート
    sorted_stages = crop_stages.includes(:temperature_requirement, :thermal_requirement, :sunshine_requirement).order(:order)
    
    # 生育ステージが未設定の場合はエラー
    if sorted_stages.empty?
      raise StandardError, "Crop '#{name}' has no growth stages. Please add growth stages with temperature and thermal requirements."
    end
    
    # stage_requirements 配列を構築（新形式）
    stage_requirements = sorted_stages.map do |stage|
      temp_req = stage.temperature_requirement
      thermal_req = stage.thermal_requirement
      sunshine_req = stage.sunshine_requirement
      
      # 必須チェック
      unless temp_req && thermal_req
        raise StandardError, "Crop '#{name}' stage '#{stage.name}' is missing required temperature or thermal requirements."
      end
      
      stage_hash = {
        'stage' => {
          'name' => stage.name,
          'order' => stage.order
        },
        'temperature' => {
          'base_temperature' => temp_req.base_temperature,
          'optimal_min' => temp_req.optimal_min,
          'optimal_max' => temp_req.optimal_max,
          'low_stress_threshold' => temp_req.low_stress_threshold,
          'high_stress_threshold' => temp_req.high_stress_threshold,
          'frost_threshold' => temp_req.frost_threshold,
          'max_temperature' => temp_req.max_temperature
        },
        'thermal' => {
          'required_gdd' => thermal_req.required_gdd
        }
      }
      
      # 日照要件がある場合のみ追加
      if sunshine_req
        stage_hash['sunshine'] = {
          'minimum_sunshine_hours' => sunshine_req.minimum_sunshine_hours,
          'target_sunshine_hours' => sunshine_req.target_sunshine_hours
        }
      end
      
      stage_hash
    end
    
    # 全ステージの required_gdd を合計
    total_gdd = sorted_stages.sum { |stage| stage.thermal_requirement&.required_gdd || 0.0 }
    
    # crop情報を構築
    {
      'crop' => {
        'crop_id' => agrr_crop_id || name.downcase.gsub(/\s+/, '_'),
        'name' => name,
        'variety' => variety || 'general',
        'area_per_unit' => area_per_unit || 0.25,
        'revenue_per_area' => revenue_per_area || 5000.0,
        'max_revenue' => (revenue_per_area || 5000.0) * 100,  # 仮の最大収益
        'groups' => groups || []
      },
      'stage_requirements' => stage_requirements
    }
  end
end


