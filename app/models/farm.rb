# frozen_string_literal: true

class Farm < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :weather_location, optional: true
  has_many :fields, dependent: :destroy

  # Enums
  enum :weather_data_status, {
    pending: 'pending',
    fetching: 'fetching',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending'

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :latitude, presence: true, 
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, 
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # Callbacks
  after_create_commit :enqueue_weather_data_fetch
  after_update_commit :broadcast_refresh_if_needed

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def coordinates
    [latitude, longitude]
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def display_name
    name.presence || "農場 ##{id}"
  end

  # 天気データ取得の進捗率（0-100）
  def weather_data_progress
    return 0 if weather_data_total_years.zero?
    (weather_data_fetched_years.to_f / weather_data_total_years * 100).round
  end

  # 天気データ取得状態の日本語表示
  def weather_data_status_text
    case weather_data_status
    when 'pending'
      '取得待ち'
    when 'fetching'
      "取得中 (#{weather_data_progress}%)"
    when 'completed'
      '完了'
    when 'failed'
      '失敗'
    else
      '不明'
    end
  end

  # 天気データ取得を開始
  def start_weather_data_fetch!
    start_year = 2000
    end_year = Date.today.year
    block_size = 5
    total_years = end_year - start_year + 1
    total_blocks = ((total_years - 1) / block_size) + 1  # 切り上げ

    update!(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 0,
      weather_data_total_years: total_blocks,  # ブロック数ベースで管理
      weather_data_last_error: nil
    )
  end

  # 天気データ取得の1ブロック分が完了
  def increment_weather_data_progress!
    new_fetched = weather_data_fetched_years + 1
    
    Rails.logger.info "🔍 [Farm##{id}] increment_weather_data_progress! called: #{weather_data_fetched_years} -> #{new_fetched}"
    
    # ブロードキャストのスロットリング判定（0.5秒に短縮）
    should_update_broadcast_time = last_broadcast_at.nil? || 
                                   Time.current - last_broadcast_at >= 0.5.second
    
    if new_fetched >= weather_data_total_years
      Rails.logger.info "🔍 [Farm##{id}] Updating to completed status"
      update!(
        weather_data_fetched_years: new_fetched,
        weather_data_status: 'completed',
        last_broadcast_at: should_update_broadcast_time ? Time.current : last_broadcast_at
      )
    else
      Rails.logger.info "🔍 [Farm##{id}] Updating progress: #{new_fetched}/#{weather_data_total_years}"
      update!(
        weather_data_fetched_years: new_fetched,
        last_broadcast_at: should_update_broadcast_time ? Time.current : last_broadcast_at
      )
    end
    
    Rails.logger.info "🔍 [Farm##{id}] update! completed"
  end

  # 天気データ取得が失敗
  def mark_weather_data_failed!(error_message)
    update!(
      weather_data_status: 'failed',
      weather_data_last_error: error_message
    )
  end

  private

  # 農場作成時に2000年からの天気カレンダーを取得
  def enqueue_weather_data_fetch
    return unless has_coordinates?

    start_year = 2000
    end_year = Date.today.year
    block_size = 5  # 5年ブロック
    
    # 5年ブロックの数を計算
    blocks = []
    current_year = start_year
    while current_year <= end_year
      block_end_year = [current_year + block_size - 1, end_year].min
      blocks << {
        start_year: current_year,
        end_year: block_end_year,
        start_date: Date.new(current_year, 1, 1),
        end_date: [Date.new(block_end_year, 12, 31), Date.today].min
      }
      current_year += block_size
    end
    
    total_years = end_year - start_year + 1
    total_blocks = blocks.size
    
    Rails.logger.info "🌾 [Farm##{id}] Starting weather data fetch for '#{name}' at #{coordinates_string}"
    Rails.logger.info "📅 [Farm##{id}] Period: #{start_year}-#{end_year} (#{total_years} years in #{total_blocks} blocks)"
    
    # ステータスを初期化（ブロック数ベースで進捗管理）
    start_weather_data_fetch!

    # 5年ブロックごとに分割して取得
    blocks.each_with_index do |block, index|
      # 1秒間隔でジョブを実行（API負荷軽減）
      FetchWeatherDataJob.set(wait: index * 1.0.seconds).perform_later(
        farm_id: id,
        latitude: latitude,
        longitude: longitude,
        start_date: block[:start_date],
        end_date: block[:end_date]
      )
    end

    Rails.logger.info "✅ [Farm##{id}] Enqueued #{total_blocks} weather data jobs (#{total_years} years) for '#{name}'"
  end

  def coordinates_string
    "#{latitude},#{longitude}"
  end

  # Turbo Streamsでリアルタイム更新をブロードキャスト（スロットリング付き）
  def broadcast_refresh_if_needed
    Rails.logger.info "🔍 [Farm##{id}] broadcast_refresh_if_needed called"
    
    # saved_change_to_X? を使う（after_commit後でも変更検知可能）
    status_changed = saved_change_to_weather_data_status?
    fetched_changed = saved_change_to_weather_data_fetched_years?
    
    Rails.logger.info "🔍 [Farm##{id}] Changes: status=#{status_changed}, fetched=#{fetched_changed}"
    Rails.logger.info "🔍 [Farm##{id}] Current: status=#{weather_data_status}, fetched=#{weather_data_fetched_years}, last_broadcast=#{last_broadcast_at}"
    
    # ステータス変更は常にブロードキャスト
    if status_changed
      Rails.logger.info "🔔 [Farm##{id}] Broadcasting: status changed"
      broadcast_now
      return
    end
    
    # 進捗更新の場合、スロットリング無効化（テスト用）
    if fetched_changed
      Rails.logger.info "🔔 [Farm##{id}] Broadcasting: progress update (throttling disabled)"
      broadcast_now
      return
    end
    
    # その他の更新は全てブロードキャスト
    Rails.logger.info "🔔 [Farm##{id}] Broadcasting: other changes"
    broadcast_now
  end
  
  def broadcast_now
    Rails.logger.info "🔍 [Farm##{id}] broadcast_now called - target: #{dom_id(self)}"
    
    # 一覧画面のカード更新
    broadcast_replace_to(
      self,
      target: dom_id(self),
      partial: "farms/farm_card_wrapper",
      locals: { farm: self }
    )
    
    # 詳細画面の天気セクション更新
    broadcast_replace_to(
      self,
      target: dom_id(self, :weather_section),
      partial: "farms/farm_weather_section",
      locals: { farm: self, fields_count: fields.count }
    )
    
    Rails.logger.info "🔍 [Farm##{id}] broadcast_replace_to completed (both index and show)"
  end
  
  # ActiveRecordのdom_idヘルパーを使えるようにする
  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end
end


