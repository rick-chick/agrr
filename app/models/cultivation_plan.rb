# frozen_string_literal: true

class CultivationPlan < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
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
  validates :plan_year, presence: true, numericality: { only_integer: true, greater_than: 2020 }, if: :plan_type_private?
  validates :planning_start_date, presence: true, if: :plan_type_private?
  validates :planning_end_date, presence: true, if: :plan_type_private?
  
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
  scope :by_plan_year, ->(year) { where(plan_year: year) }
  scope :by_plan_name, ->(name) { where(plan_name: name) }
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
  
  def phase_optimizing!(channel_class)
    update_phase!('optimizing', I18n.t('models.cultivation_plan.phases.optimizing'), channel_class)
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
              else
                I18n.t('models.cultivation_plan.phase_failed.default')
              end
    update_phase!('failed', message, channel_class)
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
      "#{name} (#{plan_year})"
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
  
  # 計画期間を設定
  def set_planning_dates_from_year!
    return unless plan_year.present?
    dates = self.class.calculate_planning_dates(plan_year)
    update!(planning_start_date: dates[:start_date], planning_end_date: dates[:end_date])
  end
  
  private
  
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
    Rails.logger.info "📡 [CultivationPlan##{id}] Channel class: #{channel_class.name}"
    
    # WebSocket接続の確立を待つ
    if optimization_phase == 'predicting_weather'
      Rails.logger.info "⏳ [CultivationPlan##{id}] Waiting for WebSocket connection for predicting_weather phase"
      sleep(2.0) # 2秒待機
    end
    
    channel_class.broadcast_to(self, payload)
    Rails.logger.info "📡 [CultivationPlan##{id}] Broadcast phase update: #{optimization_phase}"
  rescue => e
    Rails.logger.error "❌ Broadcast phase update failed for plan ##{id}: #{e.message}"
    Rails.logger.error "❌ Channel class: #{channel_class.name}"
    Rails.logger.error "❌ Payload: #{payload.inspect}"
    Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    # ブロードキャスト失敗しても処理は続行
  end
end

