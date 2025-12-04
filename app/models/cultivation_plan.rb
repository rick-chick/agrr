# frozen_string_literal: true

class CultivationPlan < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  # ⚠️ 削除順序に注意:
  # - TaskSchedule は FieldCultivation に外部キーを持つため、最初に削除する
  #   - TaskSchedule 自体は dependent: :destroy とし、内部で TaskScheduleItem を delete_all する
  #   - これにより TaskScheduleItem の外部キー制約違反を防ぐ
  # - FieldCultivation は CultivationPlanField / CultivationPlanCrop に外部キーを持つため、
  #   それらの親レコードが削除される「最後」にまとめて削除する必要がある
  # - そのため、Rails の dependent: :destroy の実行順に合わせて
  #   - まず TaskSchedule
  #   - 次に Field / Crop
  #   - 最後に FieldCultivation
  #   の順で関連を宣言する
  # これにより、複雑な関連を持つ計画でも InvalidForeignKey を回避できる
  has_many :task_schedules, dependent: :destroy
  has_many :cultivation_plan_fields, dependent: :destroy
  has_many :cultivation_plan_crops, dependent: :destroy
  has_many :field_cultivations, dependent: :destroy
  
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
  validates :farm_id, uniqueness: { 
    scope: [:user_id], 
    message: I18n.t('activerecord.errors.models.cultivation_plan.attributes.farm_id.taken')
  }, if: :plan_type_private?
  
  # == Enums ===============================================================
  enum :status, {
    pending: 'pending',
    optimizing: 'optimizing',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending', prefix: true
  
  # @deprecated plan_typeは非推奨です。代わりにrequires_weather_prediction?メソッドを使用してください
  enum :plan_type, {
    public: 'public',
    private: 'private'
  }, default: 'public', prefix: true
  
  # == Scopes ==============================================================
  scope :anonymous, -> { where(user_id: nil) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  # @deprecated 年度という概念は削除されました。このスコープは後方互換性のため残していますが、使用しないでください。
  scope :by_plan_year, ->(year) { where(plan_year: year) }
  scope :by_plan_name, ->(name) { where(plan_name: name) }
  # @deprecated 年度という概念は削除されました。このスコープは後方互換性のため残していますが、使用しないでください。
  scope :for_user_and_year, ->(user, year) { plan_type_private.by_user(user).by_plan_year(year) }
  
  # == Callbacks ===========================================================
  after_update :check_optimization_completion, if: :saved_change_to_status?
  
  # == Instance Methods ====================================================
  
  def optimization_progress
    return 0 if field_cultivations.empty?
    
    completed_count = field_cultivations.status_completed.count
    (completed_count.to_f / field_cultivations.count * 100).round
  end
  
  def start_optimizing!
    update!(status: :optimizing)
  end
  
  def complete!
    update!(status: :completed)
  end
  
  def fail!(error_message)
    update!(status: :failed, error_message: error_message)
  end
  
  # フェーズ更新メソッド
  def update_phase!(phase, message, channel_class)
    update!(optimization_phase: phase, optimization_phase_message: message)
    broadcast_phase_update(channel_class)
  end
  
  def phase_fetching_weather!(channel_class)
    update_phase!('fetching_weather', I18n.t('models.cultivation_plan.phases.fetching_weather'), channel_class)
  end
  
  def phase_predicting_weather!(channel_class)
    update_phase!('predicting_weather', I18n.t('models.cultivation_plan.phases.predicting_weather'), channel_class)
  end
  
  def phase_weather_prediction_completed!(channel_class)
    update_phase!('weather_prediction_completed', I18n.t('models.cultivation_plan.phases.weather_prediction_completed'), channel_class)
  end
  
  def phase_optimization_completed!(channel_class)
    update_phase!('optimization_completed', I18n.t('models.cultivation_plan.phases.optimization_completed'), channel_class)
  end
  
  def phase_optimizing!(channel_class)
    update_phase!('optimizing', I18n.t('models.cultivation_plan.phases.optimizing'), channel_class)
  end
  
  def phase_task_schedule_generating!(channel_class)
    update_phase!('task_schedule_generating', I18n.t('models.cultivation_plan.phases.task_schedule_generating'), channel_class)
  end
  
  def phase_completed!(channel_class)
    update_phase!('completed', I18n.t('models.cultivation_plan.phases.completed'), channel_class)
  end
  
  def phase_failed!(phase_name, channel_class)
    message = case phase_name
              when 'fetching_weather'
                I18n.t('models.cultivation_plan.phase_failed.fetching_weather')
              when 'predicting_weather'
                I18n.t('models.cultivation_plan.phase_failed.predicting_weather')
              when 'optimizing'
                I18n.t('models.cultivation_plan.phase_failed.optimizing')
              when 'task_schedule_generation'
                I18n.t('models.cultivation_plan.phase_failed.task_schedule_generation')
              else
                I18n.t('models.cultivation_plan.phase_failed.default')
              end
    update!(optimization_phase: 'failed', optimization_phase_message: message, status: 'failed')
    broadcast_phase_update(channel_class)
  end
  
  def this_year_cultivations
    field_cultivations.this_year
  end
  
  def next_year_cultivations
    field_cultivations.next_year
  end
  
  # 計画の表示名
  def display_name
    if plan_type_private?
      name = plan_name.presence || I18n.t('models.cultivation_plan.default_plan_name')
      # @deprecated plan_yearの表示は後方互換性のため残していますが、新しい計画では使用されません。
      if plan_year.present?
        "#{name} (#{plan_year})"
      elsif has_attribute?(:planning_start_date) && read_attribute(:planning_start_date).present? &&
            has_attribute?(:planning_end_date) && read_attribute(:planning_end_date).present?
        start_date = read_attribute(:planning_start_date)
        end_date = read_attribute(:planning_end_date)
        "#{name} (#{start_date.year}〜#{end_date.year})"
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
      I18n.t('models.cultivation_plan.public_plan_name')
    end
  end
  
  # 天気予測が必要かどうかを判定
  # @return [Boolean] 天気予測が必要な場合はtrue
  def requires_weather_prediction?
    # 現在は全ての計画で天気予測が必要
    # 将来的にフラグベースの制御に変更可能
    true
  end
  
  # @deprecated 年度という概念は削除されました。このメソッドは後方互換性のため残していますが、使用しないでください。
  # 計画年度から計画期間を計算（2年間）
  def self.calculate_planning_dates(plan_year)
    {
      start_date: Date.new(plan_year, 1, 1),
      end_date: Date.new(plan_year + 1, 12, 31)
    }
  end

  # public計画用の計画期間を計算（今日から来年の12月31日まで）
  def self.calculate_public_planning_dates
    {
      start_date: Date.current,
      end_date: Date.new(Date.current.year + 1, 12, 31)
    }
  end
  
  # @deprecated 年度という概念は削除されました。このメソッドは後方互換性のため残していますが、使用しないでください。
  # 計画期間を設定
  def set_planning_dates_from_year!
    return unless plan_year.present?
    dates = self.class.calculate_planning_dates(plan_year)
    update!(planning_start_date: dates[:start_date], planning_end_date: dates[:end_date])
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
      min_date = field_cultivations.pluck(:start_date).compact.min
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
      max_date = field_cultivations.pluck(:completion_date).compact.max
      return default_planning_end_date unless max_date
      max_date.end_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      default_planning_end_date
    end
  end
  
  def calculated_planning_range
    {
      start_date: calculated_planning_start_date,
      end_date: calculated_planning_end_date
    }
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
  
  def check_optimization_completion
    return unless status_optimizing?
    # 空の配列の場合は完了しない
    return if field_cultivations.empty?
    complete! if field_cultivations.all?(&:status_completed?)
  end
  
  def broadcast_phase_update(channel_class)
    payload = {
      status: status,
      progress: optimization_progress,
      phase: optimization_phase,
      phase_message: optimization_phase_message,
      message: optimization_phase_message
    }

    Rails.logger.info "📡 [CultivationPlan##{id}] Attempting to broadcast phase update: #{optimization_phase}"
    Rails.logger.info "📡 [CultivationPlan##{id}] Payload: #{payload.inspect}"
    Rails.logger.info "📡 [CultivationPlan##{id}] Channel class: #{channel_class.is_a?(String) ? channel_class : channel_class.name}"
    
    # WebSocket接続の確立を待つ
    if optimization_phase == 'predicting_weather'
      Rails.logger.info "⏳ [CultivationPlan##{id}] Waiting for WebSocket connection for predicting_weather phase"
      sleep(2.0) # 2秒待機
    end
    
    channel_class.broadcast_to(self, payload)
    Rails.logger.info "📡 [CultivationPlan##{id}] Broadcast phase update: #{optimization_phase}"
  rescue => e
    Rails.logger.error "❌ Broadcast phase update failed for plan ##{id}: #{e.message}"
    Rails.logger.error "❌ Channel class: #{channel_class.is_a?(String) ? channel_class : channel_class.name}"
    Rails.logger.error "❌ Payload: #{payload.inspect}"
    Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    # ブロードキャスト失敗しても処理は続行
  end
end

