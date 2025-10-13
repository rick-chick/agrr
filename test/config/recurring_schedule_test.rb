# frozen_string_literal: true

require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  # ========================================
  # 定期実行スケジュール設定の検証
  # ========================================
  #
  # このテストは config/recurring.yml の設定が正しく
  # Solid Queue に読み込まれているかを検証します。
  #
  # 重要性:
  #   - 定期実行は一度設定したら忘れられがち
  #   - 設定ミスで実行されないリスクがある
  #   - 本番環境でのみ問題が発覚することがある
  #
  # ========================================

  test "recurring.yml is syntactically valid YAML" do
    # YAML構文が正しいことを確認
    recurring_config = Rails.root.join('config', 'recurring.yml')
    assert File.exist?(recurring_config), "recurring.yml が存在しません"
    
    yaml_content = YAML.load_file(recurring_config, aliases: true)
    assert yaml_content.is_a?(Hash), "recurring.yml が正しいYAML形式ではありません"
  end

  test "update_reference_weather_data task is configured in recurring.yml" do
    # recurring.ymlにupdate_reference_weather_dataが定義されていることを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    
    # development環境の設定を確認
    dev_config = recurring_config['development']
    assert dev_config.present?, "development環境の設定がありません"
    
    # update_reference_weather_dataタスクの存在確認
    task_config = dev_config['update_reference_weather_data']
    assert task_config.present?, 
      "update_reference_weather_dataタスクが設定されていません\n利用可能なタスク: #{dev_config.keys.join(', ')}"
  end

  test "update_reference_weather_data has correct class name" do
    # クラス名が正しいことを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    task_config = recurring_config.dig('development', 'update_reference_weather_data') ||
                  recurring_config.dig('default', 'update_reference_weather_data')
    
    assert_equal 'UpdateReferenceWeatherDataJob', task_config['class'],
      "ジョブクラス名が正しくありません"
  end

  test "update_reference_weather_data has daily schedule" do
    # スケジュールが毎日実行であることを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    task_config = recurring_config.dig('development', 'update_reference_weather_data') ||
                  recurring_config.dig('default', 'update_reference_weather_data')
    
    schedule = task_config['schedule']
    assert schedule.present?, "スケジュールが設定されていません"
    
    # 毎日実行のスケジュール形式を確認
    # "at 3am every day" または類似のパターン
    assert_match(/every day|daily/i, schedule,
      "毎日実行のスケジュールではありません: #{schedule}")
  end

  test "update_reference_weather_data has correct queue" do
    # キュー名が正しいことを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    task_config = recurring_config.dig('development', 'update_reference_weather_data') ||
                  recurring_config.dig('default', 'update_reference_weather_data')
    
    queue = task_config['queue']
    assert_equal 'default', queue,
      "キュー名が正しくありません: #{queue}"
  end

  test "UpdateReferenceWeatherDataJob class exists and is loadable" do
    # ジョブクラスが存在し、読み込み可能であることを確認
    assert_nothing_raised do
      UpdateReferenceWeatherDataJob
    end
    
    # ApplicationJobを継承していることを確認
    assert UpdateReferenceWeatherDataJob < ApplicationJob,
      "UpdateReferenceWeatherDataJobはApplicationJobを継承すべきです"
  end

  test "recurring schedule is configured for both development and production" do
    # 両環境で設定されていることを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    
    # defaultまたは各環境で設定されているか確認
    has_default = recurring_config.dig('default', 'update_reference_weather_data').present?
    has_dev = recurring_config.dig('development', 'update_reference_weather_data').present?
    has_prod = recurring_config.dig('production', 'update_reference_weather_data').present?
    
    # defaultが設定されているか、各環境で設定されているべき
    assert(has_default || (has_dev && has_prod),
      "update_reference_weather_dataがdefaultまたは両環境で設定されていません")
  end

  test "schedule syntax is parseable by Solid Queue" do
    # Solid Queueがスケジュールを解析できることを確認
    recurring_config = YAML.load_file(Rails.root.join('config', 'recurring.yml'), aliases: true)
    task_config = recurring_config.dig('development', 'update_reference_weather_data') ||
                  recurring_config.dig('default', 'update_reference_weather_data')
    
    schedule = task_config['schedule']
    
    # Solid Queueの一般的なスケジュール形式
    valid_patterns = [
      /at\s+\d+am\s+every\s+day/,      # at 3am every day
      /at\s+\d+:\d+am\s+every\s+day/,  # at 03:00am every day
      /every\s+day\s+at\s+\d+am/,      # every day at 3am
      /daily\s+at\s+\d+am/,            # daily at 3am
      /every\s+day/,                   # every day (時刻省略)
      /at\s+\d+pm\s+every\s+day/       # at 3pm every day
    ]
    
    matches = valid_patterns.any? { |pattern| schedule =~ pattern }
    assert matches, 
      "スケジュール形式が不正です: '#{schedule}'\n" +
      "有効な形式: 'at 3am every day', 'every day at 3am', など"
  end
end

