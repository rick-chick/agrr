# frozen_string_literal: true

# CropFertilizeProfile（作物肥料プロファイル）モデル
#
# Attributes:
#   crop_id: 作物ID（必須）
#   sources: 情報源（JSON配列、テキストとして保存）
#   confidence: 信頼度（0-1、デフォルト: 0.5）
#   notes: 追加のガイダンス
#
# 役割: 作物に対する肥料施用計画の全体情報を保持
# Note: total_n, total_p, total_kは削除され、計算メソッドで取得可能
class CropFertilizeProfile < ApplicationRecord
  belongs_to :crop
  has_many :crop_fertilize_applications, dependent: :destroy

  accepts_nested_attributes_for :crop_fertilize_applications, allow_destroy: true, reject_if: :all_blank

  # sourcesをJSON配列としてシリアライズ
  serialize :sources, coder: JSON

  # デフォルト値を設定
  after_initialize do
    # Handle both String and Array cases during migration
    if sources.is_a?(String)
      self.sources = [sources]
    else
      self.sources ||= []
    end
  end

  validates :crop_id, presence: true
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  scope :recent, -> { order(created_at: :desc) }

  # 計算メソッド: 全applicationsから総量を計算
  def total_n
    crop_fertilize_applications.sum(&:total_n)
  end

  def total_p
    crop_fertilize_applications.sum(&:total_p)
  end

  def total_k
    crop_fertilize_applications.sum(&:total_k)
  end

  # agrr CLI の fertilize profile 出力形式からモデルを作成
  # @param crop [Crop] 作物モデル
  # @param profile_data [Hash] agrr fertilize profile のJSON出力
  # @return [CropFertilizeProfile] 作成されたプロファイル
  def self.from_agrr_output(crop:, profile_data:)
    profile = create!(
      crop: crop,
      sources: profile_data['sources'] || [],
      confidence: profile_data['confidence'] || 0.5,
      notes: profile_data['notes']
    )

    # applicationsを作成
    if profile_data['applications'].present?
      profile_data['applications'].each do |app_data|
        profile.crop_fertilize_applications.create!(
          application_type: app_data['type'],
          count: app_data['count'] || 1,
          schedule_hint: app_data['schedule_hint'],
          per_application_n: app_data.dig('per_application', 'N'),
          per_application_p: app_data.dig('per_application', 'P'),
          per_application_k: app_data.dig('per_application', 'K')
        )
      end
    end

    profile
  end

  # agrr CLI の fertilize profile 出力形式に変換
  # @return [Hash] agrr CLI が期待する肥料プロファイルのハッシュ
  def to_agrr_output
    {
      'crop' => {
        'crop_id' => crop.id.to_s,
        'name' => crop.name
      },
      'totals' => {
        'N' => total_n,
        'P' => total_p,
        'K' => total_k
      },
      'applications' => crop_fertilize_applications.order(:application_type, :id).map do |app|
        app_hash = {
          'type' => app.application_type,
          'count' => app.count,
          'schedule_hint' => app.schedule_hint,
          'nutrients' => {
            'N' => app.total_n,
            'P' => app.total_p,
            'K' => app.total_k
          }
        }

        # per_applicationがある場合のみ追加
        if app.per_application_n.present? || app.per_application_p.present? || app.per_application_k.present?
          app_hash['per_application'] = {
            'N' => app.per_application_n,
            'P' => app.per_application_p,
            'K' => app.per_application_k
          }
        else
          app_hash['per_application'] = nil
        end

        app_hash
      end,
      'sources' => sources || [],
      'confidence' => confidence,
      'notes' => notes
    }
  end
end

