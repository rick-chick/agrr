# frozen_string_literal: true

namespace :reference_data do
  desc "参照農場の天気データを取得（API経由）"
  task fetch_weather: :environment do
    require "net/http"
    require "json"

    # オプション解析
    farm_name_filter = ENV["FARM_NAME"]
    api_url = ENV["API_URL"] || "http://localhost:3000"

    puts "\n" + "=" * 60
    puts "参照農場の天気データ取得（API版）"
    puts "=" * 60
    puts "\nAPI URL: #{api_url}\n\n"

    # 参照農場を取得
    puts "ℹ️  参照農場を検索中..."
    farms = Farm.where(is_reference: true)
    farms = farms.where(name: farm_name_filter) if farm_name_filter

    if farms.empty?
      puts "❌ 参照農場が見つかりません"
      exit 1
    end

    puts "✅ #{farms.count}件の参照農場を発見しました\n\n"

    # 各農場の天気データを取得
    farms.each_with_index do |farm, index|
      puts "\n[#{index + 1}/#{farms.count}] 処理中: #{farm.name} (ID: #{farm.id})"
      puts "  位置: #{farm.latitude}, #{farm.longitude}"

      # API経由で天気データ取得を開始
      uri = URI("#{api_url}/api/v1/internal/farms/#{farm.id}/fetch_weather_data")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      result = JSON.parse(response.body)

      if result["error"]
        puts "❌ APIエラー: #{result['error']}"
        next
      end

      if result["message"] == "Weather data already exists"
        puts "✅ 天気データ取得済み (#{result['weather_data_count']}件のレコード)"
        next
      end

      puts "ℹ️  天気データを取得中（数分かかります）..."

      # ジョブが完了するまで待機
      last_progress = -1
      loop do
        sleep 2

        status_uri = URI("#{api_url}/api/v1/internal/farms/#{farm.id}/weather_status")
        status_response = Net::HTTP.get(status_uri)
        status_result = JSON.parse(status_response)

        if status_result["error"]
          puts "❌ ステータス取得エラー: #{status_result['error']}"
          break
        end

        status = status_result["status"]
        progress = status_result["progress"]

        if progress != last_progress
          print "\r  進捗: #{progress}% (#{status_result['fetched_blocks']}/#{status_result['total_blocks']} ブロック) [#{status}]"
          last_progress = progress
        end

        break if status == "completed"

        if status == "failed"
          puts "\n❌ 失敗: #{status_result['last_error']}"
          break
        end
      end

      puts ""

      if status_result && status_result["status"] == "completed"
        weather_count = status_result["weather_data_count"] || 0
        puts "✅ 天気データ取得完了: #{weather_count}件のレコード"
      end
    end

    puts "\n" + "=" * 60
    puts "ℹ️  データをJSON形式にエクスポート中..."

    # JSONに変換
    output = {}

    farms.reload.each do |farm|
      data_uri = URI("#{api_url}/api/v1/internal/farms/#{farm.id}/weather_data")
      data_response = Net::HTTP.get(data_uri)
      data_result = JSON.parse(data_response)

      if data_result["error"]
        puts "⚠️  #{farm.name}: #{data_result['error']}（スキップ）"
        next
      end

      unless data_result["success"]
        puts "⚠️  #{farm.name}: データ取得失敗（スキップ）"
        next
      end

      output[farm.name] = {
        name: farm.name,
        latitude: farm.latitude,
        longitude: farm.longitude,
        is_reference: farm.is_reference,
        weather_location: data_result["weather_location"],
        weather_data: data_result["weather_data"]
      }

      puts "✅ #{farm.name}: #{data_result['count']}件のデータをエクスポート"
    end

    if output.empty?
      puts "❌ エクスポートするデータがありません"
      exit 1
    end

    # ファイルに保存
    fixture_path = Rails.root.join("db/fixtures/reference_weather.json")
    FileUtils.mkdir_p(File.dirname(fixture_path))
    File.write(fixture_path, JSON.pretty_generate(output))

    puts "\n" + "=" * 60
    puts "✅ 完了！"
    puts "=" * 60
    puts "\n📄 保存先: #{fixture_path}"
    puts "📊 農場数: #{output.keys.count}"
    puts "📊 総天気レコード数: #{output.values.sum { |v| v[:weather_data].count }}"
    puts "\nℹ️  次のステップ:"
    puts "  1. ファイルを確認: cat #{fixture_path} | head -n 50"
    puts "  2. Gitにコミット: git add #{fixture_path}"
    puts ""
  end

  desc "参照作物のAI情報を取得（API経由）"
  task fetch_crops: :environment do
    require "net/http"
    require "json"

    # オプション解析
    crop_name_filter = ENV["CROP_NAME"]
    api_url = ENV["API_URL"] || "http://localhost:3000"

    puts "\n" + "=" * 60
    puts "参照作物のAI情報取得（API版）"
    puts "=" * 60
    puts "\nAPI URL: #{api_url}\n\n"

    # 参照作物を取得
    puts "ℹ️  参照作物を検索中..."
    crops = Crop.where(is_reference: true)
    crops = crops.where(name: crop_name_filter) if crop_name_filter

    if crops.empty?
      puts "❌ 参照作物が見つかりません"
      exit 1
    end

    puts "✅ #{crops.count}件の参照作物を発見しました\n\n"

    # 各作物のAI情報を取得
    crops.each_with_index do |crop, index|
      puts "\n[#{index + 1}/#{crops.count}] 処理中: #{crop.name} (#{crop.variety})"

      # 既にデータがあるかチェック
      if crop.crop_stages.any?
        has_requirements = crop.crop_stages.all? do |stage|
          stage.temperature_requirement.present? ||
          stage.sunshine_requirement.present? ||
          stage.thermal_requirement.present?
        end

        if has_requirements
          puts "✅ AI情報取得済み (#{crop.crop_stages.count}ステージ)"
          next
        end
      end

      puts "ℹ️  AI情報を取得中..."

      uri = URI("#{api_url}/api/v1/crops/ai_create")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        name: crop.name,
        variety: crop.variety
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      result = JSON.parse(response.body)

      if result["error"]
        puts "⚠️  AIエラー: #{result['error']}"
        next
      end

      if result["success"]
        puts "✅ #{result['message']}"
        puts "  - ステージ数: #{result['stages_count']}"
        puts "  - 栽培面積: #{result['area_per_unit']} m²"
        puts "  - 収益性: ¥#{result['revenue_per_area']}/m²"
      end

      sleep 1
    end

    puts "\n" + "=" * 60
    puts "ℹ️  データをJSON形式にエクスポート中..."

    # JSONに変換
    output = {}

    crops.reload.each do |crop|
      unless crop.crop_stages.any?
        puts "⚠️  #{crop.name}: ステージ情報が存在しません（スキップ）"
        next
      end

      output[crop.name] = {
        name: crop.name,
        variety: crop.variety,
        is_reference: crop.is_reference,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area,
        crop_stages: crop.crop_stages.order(:order).map do |stage|
          stage_hash = {
            name: stage.name,
            order: stage.order
          }

          if stage.temperature_requirement
            stage_hash[:temperature_requirement] = {
              base_temperature: stage.temperature_requirement.base_temperature,
              optimal_min: stage.temperature_requirement.optimal_min,
              optimal_max: stage.temperature_requirement.optimal_max,
              low_stress_threshold: stage.temperature_requirement.low_stress_threshold,
              high_stress_threshold: stage.temperature_requirement.high_stress_threshold,
              frost_threshold: stage.temperature_requirement.frost_threshold,
              sterility_risk_threshold: stage.temperature_requirement.sterility_risk_threshold
            }
          end

          if stage.sunshine_requirement
            stage_hash[:sunshine_requirement] = {
              minimum_sunshine_hours: stage.sunshine_requirement.minimum_sunshine_hours,
              target_sunshine_hours: stage.sunshine_requirement.target_sunshine_hours
            }
          end

          if stage.thermal_requirement
            stage_hash[:thermal_requirement] = {
              required_gdd: stage.thermal_requirement.required_gdd
            }
          end

          stage_hash
        end
      }

      puts "✅ #{crop.name}: #{crop.crop_stages.count}ステージをエクスポート"
    end

    if output.empty?
      puts "❌ エクスポートするデータがありません"
      exit 1
    end

    # ファイルに保存
    fixture_path = Rails.root.join("db/fixtures/reference_crops.json")
    FileUtils.mkdir_p(File.dirname(fixture_path))
    File.write(fixture_path, JSON.pretty_generate(output))

    puts "\n" + "=" * 60
    puts "✅ 完了！"
    puts "=" * 60
    puts "\n📄 保存先: #{fixture_path}"
    puts "📊 作物数: #{output.keys.count}"
    puts "📊 総ステージ数: #{output.values.sum { |v| v[:crop_stages].count }}"
    puts "\nℹ️  次のステップ:"
    puts "  1. ファイルを確認: cat #{fixture_path} | head -n 50"
    puts "  2. Gitにコミット: git add #{fixture_path}"
    puts ""
  end
end
