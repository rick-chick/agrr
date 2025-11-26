# frozen_string_literal: true

# AgriculturalTask（農業タスク）モデル
#
# Attributes:
#   name: タスク名（必須、一意）
#   description: 説明文
#   time_per_sqm: 単位面積あたりの所要時間（float）
#   weather_dependency: 天候依存度（'low', 'medium', 'high'）
#   required_tools: 必要な工具（JSON配列として保存）
#   skill_level: スキルレベル（'beginner', 'intermediate', 'advanced'）
#   is_reference: 参照タスクフラグ（デフォルト: true）
#   user_id: 所有ユーザー（参照タスクの場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用タスク
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人のタスク
#     - user_idが設定される（ユーザー所有）
#
# agrr CLIとの連携:
#   - to_agrr_format メソッドでagrr CLIの期待する形式に変換
#   - to_agrr_format_array メソッドで複数のタスクを配列に変換
class AgriculturalTask < ApplicationRecord
  belongs_to :user, optional: true
  has_many :crop_task_templates, dependent: :destroy
  has_many :crops, through: :crop_task_templates
  has_many :crop_task_schedule_blueprints, dependent: :restrict_with_exception
  
  # required_toolsをJSON配列としてシリアライズ
  serialize :required_tools, coder: JSON
  
  # デフォルト値を設定
  after_initialize do
    self.required_tools ||= []
    self.is_reference = true if is_reference.nil?
  end
  
  # バリデーション
  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :time_per_sqm, numericality: { greater_than: 0, allow_nil: true }
  validate :name_uniqueness_scope
  validates :source_agricultural_task_id, uniqueness: { scope: :user_id }, allow_nil: true
  
  # スコープ
  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }
  
  # agrr CLI の agricultural-tasks フォーマットに変換
  # @return [Hash] agrr CLI が期待するタスクのハッシュ
  def to_agrr_format
    {
      'task_id' => id.to_s,
      'name' => name,
      'description' => description,
      'time_per_sqm' => time_per_sqm&.to_f,
      'weather_dependency' => weather_dependency,
      'required_tools' => required_tools || [],
      'skill_level' => skill_level
    }.compact
  end
  
  # 複数のタスクをagrr CLI形式の配列に変換
  # @param tasks [ActiveRecord::Relation<AgriculturalTask>] タスクのコレクション
  # @return [Array<Hash>] agrr CLI形式のタスク配列
  def self.to_agrr_format_array(tasks)
    tasks.map(&:to_agrr_format)
  end
  
  private
  
  def name_uniqueness_scope
    if is_reference?
      # 参照タスクは名前が一意
      existing = AgriculturalTask.reference.where(name: name)
      existing = existing.where.not(id: id) if persisted?
      errors.add(:name, :taken) if existing.exists?
    else
      # ユーザー所有タスクは同一ユーザー内で名前が一意
      existing = AgriculturalTask.user_owned.where(user_id: user_id, name: name)
      existing = existing.where.not(id: id) if persisted?
      errors.add(:name, :taken) if existing.exists?
    end
  end

  # 参照タスクは user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end

