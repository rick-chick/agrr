# frozen_string_literal: true

class CultivationPlan < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  # ⚠️ 削除順序に注意:
  # - TaskSchedule は FieldCultivation に外部キーを持つため、最初に削除する
  #   - TaskSchedule 自体は dependent: :destroy とし、内部で TaskScheduleItem を delete_all する
  # - FieldCultivation は CultivationPlanField / CultivationPlanCrop の両方から has_many されるため、
  #   Field/Crop を先に消すと二重に FC を destroy しようとして InvalidForeignKey になる。
  #   そのため Plan 直下の field_cultivations を、Field/Crop より先に宣言して先に削除する。
  # - CultivationPlanField / CultivationPlanCrop 側は dependent: :destroy を付けず、
  #   単体削除時のみ before_destroy で FC を落とす（plan 全体削除では既に FC は無い）
  has_many :task_schedules, dependent: :destroy
  has_many :field_cultivations, dependent: :destroy
  has_many :cultivation_plan_fields, dependent: :destroy
  has_many :cultivation_plan_crops, dependent: :destroy

  # crops との関連付け（CultivationPlanCrop を通じて）
  has_many :crops, through: :cultivation_plan_crops

  # == Serialization =======================================================
  serialize :predicted_weather_data, coder: JSON

  # == Validations =========================================================
  validates :total_area, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending optimizing completed failed] }
  validates :plan_type, presence: true, inclusion: { in: %w[public private] }
  validates :user_id, presence: true, if: :plan_type_private?
  # @deprecated plan_yearは後方互換性のためオプショナル（既存データのため）
  # 年度という概念は削除されました。新しい計画ではplan_yearはnilになります。
  validates :plan_year, numericality: { only_integer: true, greater_than: 2020 }, allow_nil: true, if: :plan_type_private?
  validates :planning_start_date, presence: true, if: :plan_type_private?
  validates :planning_end_date, presence: true, if: :plan_type_private?

  # 農場とユーザで一意制約（private計画のみ、plan_yearを除外）
  # message: I18n.t はクラスロード時に評価されるためロケール依存の失敗を引き起こす。
  # Rails 7+ の翻訳ベースバリデーションを使用（検証時に評価される）
  validates :farm_id, uniqueness: {
    scope: [ :user_id ],
    message: :taken
  }, if: :plan_type_private?

  # == Enums ===============================================================
  enum :status, {
    pending: "pending",
    optimizing: "optimizing",
    completed: "completed",
    failed: "failed"
  }, default: "pending", prefix: true

  enum :plan_type, {
    public: "public",
    private: "private"
  }, default: "public", prefix: true

  # == Scopes ==============================================================
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }

  # == Instance Methods ====================================================

  # 計画の表示名
  def display_name
    if plan_type_private?
      name = plan_name.presence || I18n.t("models.cultivation_plan.default_plan_name")
      # @deprecated plan_yearの表示は後方互換性のため残していますが、新しい計画では使用されません。
      if plan_year.present?
        "#{name} (#{plan_year})"
      elsif has_attribute?(:planning_start_date) && read_attribute(:planning_start_date).present? &&
            has_attribute?(:planning_end_date) && read_attribute(:planning_end_date).present?
        # 計画期間を表示名に付与していたが不要のため、期間は付けずに名称のみ返す
        name
      elsif !has_attribute?(:planning_start_date) || !has_attribute?(:planning_end_date)
        # カラムが存在しない場合は計算メソッドを使用
        start_date = calculated_planning_start_date
        end_date = calculated_planning_end_date
        if start_date && end_date
          "#{name} (#{start_date.year}〜#{end_date.year})"
        else
          name
        end
      else
        name
      end
    else
      I18n.t("models.cultivation_plan.public_plan_name")
    end
  end

  # @deprecated 年度という概念は削除されました。このメソッドは後方互換性のため残していますが、使用しないでください。
  # 計画年度から計画期間を計算（2年間）
  def self.calculate_planning_dates(plan_year)
    Domain::CultivationPlan::Calculators::PlanningDateCalculator.calculate_planning_dates(plan_year)
  end

  # 計画期間をメソッドとして計算
  # @deprecated plan_yearの参照は後方互換性のため残していますが、新しい計画ではplan_yearはnilです。
  def calculated_planning_start_date
    # plan_yearが設定されている場合は保存されているカラムを優先（後方互換性のため）
    if plan_year.present? && has_attribute?(:planning_start_date) && read_attribute(:planning_start_date).present?
      return read_attribute(:planning_start_date)
    end

    # plan_yearが設定されていない場合はfield_cultivationsから計算
    if field_cultivations.any?
      # includes/preloadでロードされたコレクションの場合はメモリ上のデータを使用
      # pluckはDBクエリを発行するため、loaded?でチェックしてメモリ上のデータを使用する。
      # ただし環境やライブラリの相互作用でpluckがエラーを投げるケースがあるため、
      # 安全のため例外を補足してメモリ走査にフォールバックする。
      if field_cultivations.loaded?
        min_date = field_cultivations.map(&:start_date).compact.min
      else
        begin
          min_date = field_cultivations.pluck(:start_date).compact.min
        rescue => e
          Rails.logger.warn "⚠️ pluck failed in calculated_planning_start_date, falling back to in-memory map: #{e.class} #{e.message}"
          min_date = field_cultivations.map(&:start_date).compact.min
        end
      end
      return default_planning_start_date unless min_date
      min_date.beginning_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      default_planning_start_date
    end
  end

  def calculated_planning_end_date
    # @deprecated plan_yearの参照は後方互換性のため残していますが、新しい計画ではplan_yearはnilです。
    # plan_yearが設定されている場合は保存されているカラムを優先（後方互換性のため）
    if plan_year.present? && has_attribute?(:planning_end_date) && read_attribute(:planning_end_date).present?
      return read_attribute(:planning_end_date)
    end

    # plan_yearが設定されていない場合はfield_cultivationsから計算
    if field_cultivations.any?
      # includes/preloadでロードされたコレクションの場合はメモリ上のデータを使用
      # pluckはDBクエリを発行するため、loaded?でチェックしてメモリ上のデータを使用する。
      # ただし環境やライブラリの相互作用でpluckがエラーを投げるケースがあるため、
      # 安全のため例外を補足してメモリ走査にフォールバックする。
      if field_cultivations.loaded?
        max_date = field_cultivations.map(&:completion_date).compact.max
      else
        begin
          max_date = field_cultivations.pluck(:completion_date).compact.max
        rescue => e
          Rails.logger.warn "⚠️ pluck failed in calculated_planning_end_date, falling back to in-memory map: #{e.class} #{e.message}"
          max_date = field_cultivations.map(&:completion_date).compact.max
        end
      end
      return default_planning_end_date unless max_date
      max_date.end_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      default_planning_end_date
    end
  end

  # 互換性のためのエイリアス（段階的移行用）
  # 注意: カラムが存在する場合はカラムを優先し、存在しない場合は計算メソッドを使用
  # バリデーションではカラムの値のみをチェックするため、カラムがnilの場合はnilを返す
  def planning_start_date
    if has_attribute?(:planning_start_date)
      read_attribute(:planning_start_date)
    else
      calculated_planning_start_date
    end
  end

  def planning_end_date
    if has_attribute?(:planning_end_date)
      read_attribute(:planning_end_date)
    else
      calculated_planning_end_date
    end
  end

  # 予測/最適化用のターゲット終了日
  #
  # - プライベート計画: 現行の計画終了日のロジック（calculated_planning_end_date）に従う
  # - 公開計画: 「翌年の12月31日」までを予測/最適化のホライズンとして扱う
  #
  # 表示用の終了日（planning_end_date）とは責務を分離し、public_plans 向けの
  # 予測ホライズンをユースケース側で明示的に制御するためのメソッド。
  def prediction_target_end_date
    if plan_type_private?
      calculated_planning_end_date
    else
      Date.new(Date.current.year + 1, 12, 31)
    end
  end

  private

  def default_planning_start_date
    # プライベート計画: 現在年の1月1日
    # 公開計画: 今日
    if plan_type_private?
      Date.current.beginning_of_year
    else
      Date.current
    end
  end

  def default_planning_end_date
    # プライベート計画: 次の年の12月31日
    # 公開計画: 今年の12月31日
    if plan_type_private?
      Date.new(Date.current.year + 1, 12, 31)
    else
      Date.current.end_of_year
    end
  end

end
