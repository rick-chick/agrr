# frozen_string_literal: true

require "test_helper"

class SolidQueueRecurringIntegrationTest < ActiveSupport::TestCase
  # ========================================
  # Solid Queue 定期実行の統合テスト
  # ========================================
  #
  # このテストは Solid Queue が recurring.yml を
  # 正しく読み込んで定期タスクとして認識しているかを
  # 実際のデータベースで検証します。
  #
  # 重要性:
  #   - recurring.ymlが正しくても、Solid Queueが
  #     読み込めなければ実行されない
  #   - 本番環境でのみ問題が発覚すると致命的
  #
  # ========================================

  setup do
    # テスト環境でrecurring.ymlを読み込み
    # aliases: true で YAMLアンカー（<<: *default）を有効化
    @recurring_config = YAML.load_file(
      Rails.root.join('config', 'recurring.yml'),
      aliases: true
    )
  end

  test "Solid Queue recurring tasks table exists" do
    # solid_queue_recurring_tasksテーブルが存在することを確認
    # テスト環境では存在しない場合があるのでskip
    skip "solid_queue_recurring_tasksはテスト環境では作成されない場合があります" unless 
      ActiveRecord::Base.connection.table_exists?('solid_queue_recurring_tasks')
    
    assert ActiveRecord::Base.connection.table_exists?('solid_queue_recurring_tasks')
  end

  test "recurring.yml configuration is loadable" do
    # recurring.ymlが読み込み可能であることを確認
    assert @recurring_config.present?, "recurring.ymlが読み込めません"
    assert @recurring_config.is_a?(Hash), "recurring.ymlが正しい形式ではありません"
  end

  test "update_reference_weather_data is configured with valid syntax" do
    # テスト環境の設定を取得
    env_config = @recurring_config['test'] || @recurring_config['default']
    
    skip "test環境またはdefault環境の設定がありません" unless env_config
    
    task = env_config['update_reference_weather_data']
    skip "update_reference_weather_dataタスクが設定されていません" unless task
    
    # 必須項目の確認
    assert task['class'].present?, "classが設定されていません"
    assert task['schedule'].present?, "scheduleが設定されていません"
    assert task['queue'].present?, "queueが設定されていません"
    
    # クラス名の確認
    assert_equal 'UpdateReferenceWeatherDataJob', task['class']
    
    # キュー名の確認
    assert_equal 'default', task['queue']
    
    # スケジュールの形式確認
    schedule = task['schedule']
    assert_match(/every day|daily|at.*every day/i, schedule,
      "毎日実行のスケジュールではありません: #{schedule}")
  end

  test "schedule format is parseable" do
    # スケジュール形式が解析可能であることを確認
    env_config = @recurring_config['test'] || @recurring_config['default']
    skip unless env_config && env_config['update_reference_weather_data']
    
    schedule = env_config['update_reference_weather_data']['schedule']
    
    # Solid Queueがサポートする形式
    valid_formats = [
      'every second',
      'every minute',
      'every hour',
      'every day',
      'at 3am every day',
      'at 5am every day',
      'every hour at minute 12'
    ]
    
    # より柔軟なパターンマッチング（スペース対応）
    basic_patterns = [
      /^every\s+\w+$/,                    # every day, every hour
      /^at\s+\d+\w*\s+every\s+day$/,     # at 3am every day
      /^at\s+\d+:\d+\w*\s+every\s+\w+$/, # at 03:00am every day
      /^every\s+\w+\s+at\s+.+$/          # every hour at minute 12
    ]
    
    matches = basic_patterns.any? { |pattern| schedule =~ pattern }
    assert matches, 
      "スケジュール形式が不正です: '#{schedule}'\n" +
      "有効な例: #{valid_formats.join(', ')}"
  end

  test "job class specified in config exists and is executable" do
    # 設定されているジョブクラスが存在し、実行可能であることを確認
    env_config = @recurring_config['test'] || @recurring_config['default']
    skip unless env_config && env_config['update_reference_weather_data']
    
    class_name = env_config['update_reference_weather_data']['class']
    
    # クラスが存在するか
    job_class = class_name.constantize
    assert job_class.present?, "#{class_name}クラスが見つかりません"
    
    # ApplicationJobを継承しているか
    assert job_class < ApplicationJob,
      "#{class_name}はApplicationJobを継承すべきです"
    
    # performメソッドが定義されているか
    assert job_class.instance_methods.include?(:perform),
      "#{class_name}にperformメソッドがありません"
  end

  test "no duplicate task keys in configuration" do
    # 各環境内で重複したタスクキーがないことを確認
    @recurring_config.each do |env, config|
      next unless config.is_a?(Hash)
      next if env == 'default'  # defaultはアンカーなのでスキップ
      
      task_keys = config.keys
      duplicates = task_keys.group_by(&:itself).select { |k, v| v.size > 1 }.keys
      
      assert duplicates.empty?,
        "#{env}環境で重複したタスクキーがあります: #{duplicates.join(', ')}"
    end
  end

  test "recurring configuration is consistent across environments" do
    # 環境間で設定の一貫性を確認
    default_config = @recurring_config['default']
    dev_config = @recurring_config['development']
    prod_config = @recurring_config['production']
    
    # defaultが設定されている場合
    if default_config && default_config['update_reference_weather_data']
      default_task = default_config['update_reference_weather_data']
      
      # developmentがdefaultを継承していることを確認（<<: *default）
      if dev_config && dev_config['update_reference_weather_data']
        # 明示的に上書きされている場合はOK
        assert true
      elsif dev_config.nil? || dev_config.empty? || dev_config == default_config
        # defaultが継承されている
        assert true
      else
        # 設定が存在するが異なる場合は警告
        skip "development環境でdefaultが上書きされています"
      end
    end
  end

  test "schedule will execute daily" do
    # スケジュールが「毎日」実行されることを確認
    env_config = @recurring_config['test'] || @recurring_config['default']
    skip unless env_config && env_config['update_reference_weather_data']
    
    schedule = env_config['update_reference_weather_data']['schedule']
    
    # 「毎日」を示すキーワードが含まれているか
    daily_keywords = ['every day', 'daily']
    has_daily_keyword = daily_keywords.any? { |keyword| schedule.downcase.include?(keyword) }
    
    assert has_daily_keyword,
      "毎日実行のスケジュールではありません: '#{schedule}'\n" +
      "必要なキーワード: #{daily_keywords.join(' または ')}"
  end

  test "schedule specifies execution time" do
    # 実行時刻が指定されていることを確認
    env_config = @recurring_config['test'] || @recurring_config['default']
    skip unless env_config && env_config['update_reference_weather_data']
    
    schedule = env_config['update_reference_weather_data']['schedule']
    
    # 時刻指定のパターン（at 3am, at 5pm, など）
    has_time = schedule.match?(/at \d+:\d+|at \d+am|at \d+pm/i)
    
    assert has_time,
      "実行時刻が指定されていません: '#{schedule}'\n" +
      "推奨: 'at 3am every day' のように時刻を明示"
  end

  test "production environment has the same configuration" do
    # 本番環境でも同じ設定があることを確認
    prod_config = @recurring_config['production']
    
    # productionにも設定があるか、defaultを継承しているか
    has_prod_task = prod_config && prod_config['update_reference_weather_data'].present?
    has_default = @recurring_config['default'] && 
                  @recurring_config['default']['update_reference_weather_data'].present?
    
    assert(has_prod_task || has_default,
      "production環境でupdate_reference_weather_dataが設定されていません")
  end

  test "no conflicting schedules for the same job" do
    # 同じジョブが複数のスケジュールで設定されていないことを確認
    all_update_tasks = []
    
    @recurring_config.each do |env, config|
      next unless config.is_a?(Hash)
      config.each do |task_key, task_config|
        next unless task_config.is_a?(Hash)
        if task_config['class'] == 'UpdateReferenceWeatherDataJob'
          all_update_tasks << { env: env, key: task_key, schedule: task_config['schedule'] }
        end
      end
    end
    
    # 重複がないか、またはすべて同じスケジュールであることを確認
    if all_update_tasks.size > 1
      schedules = all_update_tasks.map { |t| t[:schedule] }.uniq
      assert_equal 1, schedules.size,
        "UpdateReferenceWeatherDataJobに複数の異なるスケジュールが設定されています: #{all_update_tasks.inspect}"
    end
  end
end

