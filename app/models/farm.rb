# frozen_string_literal: true

# Farm（農場）モデル
#
# is_reference フラグについて:
#   - true: システムが提供する参照用農場（栽培地域）
#     - 管理者のみが管理画面で表示・編集可能
#     - 一般ユーザーからは見えない（無料プラン作成時の地域選択でのみ使用）
#     - アノニマスユーザーに所属する必要がある
#   - false: ユーザーが作成した個人の農場
#     - 作成したユーザーのみが管理可能
#
class Farm < ApplicationRecord
  # Serialization
  serialize :predicted_weather_data, coder: JSON

  # Associations
  belongs_to :user
  belongs_to :weather_location, optional: true
  has_many :fields, dependent: :destroy
  has_many :free_crop_plans, dependent: :destroy

  # Enums
  enum :weather_data_status, {
    pending: "pending",
    fetching: "fetching",
    completed: "completed",
    failed: "failed"
  }, default: "pending"

  # Callbacks
  # 経度正規化・座標変更時の気象リセット・ブロードキャストは domain Interactor 経由

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :latitude, presence: true,
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :region, inclusion: { in: %w[jp us in] }, allow_nil: true
  validates :source_farm_id, uniqueness: { scope: :user_id }, allow_nil: true

  # ユーザー農場の件数制限は Domain::Farm::Policies::FarmCreateLimitPolicy（Interactor）で実施
  validates :user, presence: true

  # 参照農場はアノニマスユーザーにのみ設定可能（複数の参照農場を許可）
  validate :reference_farm_must_belong_to_anonymous_user

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }
  scope :reference, -> { where(is_reference: true).order(latitude: :desc) }  # 北から南の順
  scope :user_owned, -> { where(is_reference: false) }

  # Instance methods
  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def display_name
    name.presence || I18n.t("models.farm.default_name", id: id)
  end

  def reference?
    is_reference
  end

  # 天気データ取得の進捗率（0-100）— 表示用。永続化更新は domain 経由。
  def weather_data_progress
    Domain::Farm::Calculators::FarmWeatherProgressCalculator.progress_percent(
      fetched: weather_data_fetched_years,
      total: weather_data_total_years
    )
  end

  private

  # 参照農場はアノニマスユーザーに属する必要がある（複数の参照農場を地域ごとに許可）
  def reference_farm_must_belong_to_anonymous_user
    if is_reference && user && !user.anonymous?
      errors.add(:is_reference, :reference_only_anonymous)
    end
  end

end
