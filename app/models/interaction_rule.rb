# frozen_string_literal: true

# InteractionRule（作物相互作用ルール）モデル
#
# Attributes:
#   rule_type: ルールタイプ（必須）
#     - continuous_cultivation: 連作
#     将来的な拡張:
#     - companion_planting: 混植（コンパニオンプランツ）
#   source_group: 影響を与える元のグループ名（必須）
#   target_group: 影響を受ける対象のグループ名（必須）
#   impact_ratio: 影響係数（必須、0以上の数値）
#     - 1.0 = 影響なし（中立）
#     - 0.7 = 30%減少（ネガティブな影響）
#     - 1.2 = 20%増加（ポジティブな影響）
#     - 0.0 = 栽培不可
#   is_directional: 方向性の有無（デフォルト: true）
#     - true: 方向性あり（source → target のみ）
#     - false: 双方向（相互に影響）
#   description: ルールの説明文（任意）
#   user_id: 所有ユーザー（参照ルールの場合はnull）
#   is_reference: 参照ルールフラグ
#
# is_reference フラグについて:
#   - true: システムが提供する参照用ルール（標準の連作・輪作効果など）
#     - 管理者のみが管理画面で表示・編集可能
#     - 一般ユーザーからは見えない（作付け計画時に自動適用）
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人のカスタムルール
#     - 作成したユーザーのみが管理可能
#
# agrr CLIとの連携:
#   - to_agrr_format メソッドでagrr CLIの期待する形式に変換
#   - as_json メソッドでJSON出力をカスタマイズ
class InteractionRule < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :rule_type, presence: true
  validates :source_group, presence: true
  validates :target_group, presence: true
  validates :impact_ratio, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :is_reference, inclusion: { in: [true, false] }
  validates :source_interaction_rule_id, uniqueness: { scope: :user_id }, allow_nil: true

  # Scopes
  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  # デフォルト値を設定
  after_initialize do
    self.is_directional = true if is_directional.nil?
  end

  # agrr CLI の interaction-rules-file フォーマットに変換
  # @return [Hash] agrr CLI が期待する相互作用ルールのハッシュ
  def to_agrr_format
    {
      'rule_id' => "rule_#{id}",
      'rule_type' => rule_type,
      'source_group' => source_group,
      'target_group' => target_group,
      'impact_ratio' => impact_ratio.to_f,
      'is_directional' => is_directional,
      'description' => description
    }.compact
  end

  # JSON出力をカスタマイズ
  def as_json(options = {})
    result = super(options.merge(
      only: [:id, :rule_type, :source_group, :target_group, :impact_ratio, :is_directional, :description, :user_id, :is_reference],
      methods: []
    ))
    # impact_ratioをFloatに変換（DBから取得すると文字列になる場合がある）
    result['impact_ratio'] = result['impact_ratio'].to_f if result['impact_ratio']
    result
  end

  # 複数のルールをagrr CLI形式の配列に変換
  # @param rules [ActiveRecord::Relation<InteractionRule>] ルールのコレクション
  # @return [Array<Hash>] agrr CLI形式のルール配列
  def self.to_agrr_format_array(rules)
    rules.map(&:to_agrr_format)
  end
end

