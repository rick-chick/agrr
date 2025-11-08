# frozen_string_literal: true

# Crop（作物）モデル
#
# Attributes:
#   name: 作物名（必須）
#   variety: 品種名（任意）
#   is_reference: 参照作物フラグ
#   area_per_unit: 単位あたりの栽培面積（㎡）- 正の数値のみ
#   revenue_per_area: 面積あたりの収益（円/㎡）- 0以上の数値のみ
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
  has_many :crop_pests, dependent: :destroy
  has_many :pests, through: :crop_pests
  has_many :agricultural_task_crops, dependent: :destroy
  has_many :agricultural_tasks, through: :agricultural_task_crops

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
  validates :source_crop_id, uniqueness: { scope: :user_id }, allow_nil: true
  
  # ユーザー作物の件数制限（20件まで）
  validates :user, presence: true, unless: :is_reference?
  validate :user_crop_count_limit, unless: :is_reference?

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  # agrr CLI の crop-requirement-file フォーマットに変換（新形式）
  # @return [Hash] agrr CLI が期待する作物要件のハッシュ
  # @raise [StandardError] 必須データが未設定の場合
  def to_agrr_requirement
    # crop_stagesをorderでソート
    sorted_stages = crop_stages.includes(:temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement).order(:order)
    
    # 生育ステージが未設定の場合はエラー
    if sorted_stages.empty?
      raise StandardError, "Crop '#{name}' has no growth stages. Please add growth stages with temperature and thermal requirements."
    end
    
    # stage_requirements 配列を構築（新形式）
    stage_requirements = sorted_stages.map do |stage|
      temp_req = stage.temperature_requirement
      thermal_req = stage.thermal_requirement
      sunshine_req = stage.sunshine_requirement
      nutrient_req = stage.nutrient_requirement
      
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
          # Use 50.0 as default max_temperature if nil (Python AGRR code requires this field)
          # 50°C is higher than any realistic crop tolerance
          'max_temperature' => temp_req.max_temperature || 50.0
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
      
      # 栄養素要件がある場合のみ追加
      if nutrient_req
        stage_hash['nutrients'] = {
          'daily_uptake' => {
            'N' => nutrient_req.daily_uptake_n,
            'P' => nutrient_req.daily_uptake_p,
            'K' => nutrient_req.daily_uptake_k
          }
        }
      end
      
      stage_hash
    end
    
    # 全ステージの required_gdd を合計
    total_gdd = sorted_stages.sum { |stage| stage.thermal_requirement&.required_gdd || 0.0 }
    
    # crop情報を構築
    {
      'crop' => {
        'crop_id' => id.to_s,
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

  # agrr CLI の pest 出力形式からPestを作成または更新し、Cropと関連付け
  # @param pest_output_data [Hash] agrr pest コマンドのJSON出力（data部分）
  # @param is_reference [Boolean] Pestを参照データとして作成するか（デフォルト: true）
  # @return [Array<Pest>] 作成または更新されたPestの配列
  # @raise [StandardError] 必須データが欠損している場合
  def associate_pests_from_agrr_output(pest_output_data:, is_reference: true)
    unless pest_output_data['pests'].is_a?(Array)
      raise StandardError, "Invalid pest_output_data: 'pests' must be an array"
    end

    associated_pests = []

    pest_output_data['pests'].each do |pest_data|
      pest = Pest.from_agrr_output(pest_data: pest_data, is_reference: is_reference)
      
      # CropとPestを関連付け（既存の関連は上書きしない）
      CropPest.find_or_create_by!(crop: self, pest: pest)
      
      associated_pests << pest
    end

    associated_pests
  end

  private

  def user_crop_count_limit
    return if user.nil? || is_reference?
    
    existing_crops_count = user.crops.where(is_reference: false).count
    # 新規作成の場合は既存の件数、更新の場合は既存の件数-1（自分自身を除く）
    current_count = new_record? ? existing_crops_count : existing_crops_count - 1
    
    if current_count >= 20
      errors.add(:user, :crop_limit_exceeded)
    end
  end
end
