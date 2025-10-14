# frozen_string_literal: true

class CultivationPlan < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  has_many :cultivation_plan_fields, dependent: :destroy
  has_many :cultivation_plan_crops, dependent: :destroy
  has_many :field_cultivations, dependent: :destroy
  
  # == Validations =========================================================
  validates :total_area, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending optimizing completed failed] }
  
  # == Enums ===============================================================
  enum :status, {
    pending: 'pending',
    optimizing: 'optimizing',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending', prefix: true
  
  # == Scopes ==============================================================
  scope :anonymous, -> { where(user_id: nil) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :recent, -> { order(created_at: :desc) }
  
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
    broadcast_phase_update
  end
  
  def fail!(error_message)
    update!(status: :failed, error_message: error_message)
    broadcast_phase_update
  end
  
  # フェーズ更新メソッド
  def update_phase!(phase, message)
    update!(optimization_phase: phase, optimization_phase_message: message)
    broadcast_phase_update
  end
  
  def phase_fetching_weather!
    update_phase!('fetching_weather', '気象データを取得しています...')
  end
  
  def phase_predicting_weather!
    update_phase!('predicting_weather', '気象データを予測しています...')
  end
  
  def phase_optimizing!
    update_phase!('optimizing', '最適化処理中...')
  end
  
  def phase_completed!
    update_phase!('completed', '最適化が完了しました')
  end
  
  def phase_failed!(phase_name)
    message = case phase_name
              when 'fetching_weather'
                '気象データの取得に失敗しました'
              when 'predicting_weather'
                '気象データの予測に失敗しました'
              when 'optimizing'
                '最適化処理に失敗しました'
              else
                '処理に失敗しました'
              end
    update_phase!('failed', message)
  end
  
  def this_year_cultivations
    field_cultivations.this_year
  end
  
  def next_year_cultivations
    field_cultivations.next_year
  end
  
  private
  
  def check_optimization_completion
    return unless status_optimizing?
    complete! if field_cultivations.all?(&:status_completed?)
  end
  
  def broadcast_phase_update
    OptimizationChannel.broadcast_to(
      self,
      {
        status: status,
        progress: optimization_progress,
        phase: optimization_phase,
        phase_message: optimization_phase_message,
        message: optimization_phase_message
      }
    )
  rescue => e
    Rails.logger.error "❌ Broadcast phase update failed for plan ##{id}: #{e.message}"
    # ブロードキャスト失敗しても処理は続行
  end
end

