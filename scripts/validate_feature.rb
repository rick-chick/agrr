#!/usr/bin/env ruby
# frozen_string_literal: true

# 新機能の基本的なチェックを自動化するスクリプト
# 使い方: ruby scripts/validate_feature.rb --feature crop_palette

require 'optparse'
require 'pathname'
require 'json'

class FeatureValidator
  attr_reader :feature_name, :errors, :warnings

  def initialize(feature_name)
    @feature_name = feature_name
    @errors = []
    @warnings = []
    @root = Pathname.new(__dir__).parent
  end

  def validate!
    puts "=" * 80
    puts "新機能検証: #{feature_name}"
    puts "=" * 80
    puts

    check_javascript_files
    check_css_files
    check_layout_files
    check_manifest
    check_compiled_assets
    check_routes

    print_results
  end

  private

  def check_javascript_files
    puts "📝 JavaScriptファイルをチェック中..."

    js_path = @root.join("app/assets/javascripts/#{feature_name}.js")
    bundled_js_path = @root.join("app/javascript/#{feature_name}.js")

    if js_path.exist?
      puts "  ✅ #{js_path.relative_path_from(@root)} が存在します"
      check_content_for_in_views(feature_name, :javascripts)
    elsif bundled_js_path.exist?
      puts "  ✅ #{bundled_js_path.relative_path_from(@root)} が存在します（バンドル用）"
    else
      @warnings << "#{feature_name}.js が見つかりません（app/assets/javascripts/ または app/javascript/）"
    end
    puts
  end

  def check_css_files
    puts "🎨 CSSファイルをチェック中..."

    css_paths = [
      @root.join("app/assets/stylesheets/features/#{feature_name}.css"),
      @root.join("app/assets/stylesheets/#{feature_name}.css")
    ]

    found = false
    css_paths.each do |css_path|
      if css_path.exist?
        puts "  ✅ #{css_path.relative_path_from(@root)} が存在します"
        check_stylesheet_link_in_layouts(feature_name)
        found = true
        break
      end
    end

    unless found
      @warnings << "#{feature_name}.css が見つかりません（app/assets/stylesheets/features/ または app/assets/stylesheets/）"
    end
    puts
  end

  def check_layout_files
    puts "📄 レイアウトファイルをチェック中..."

    layouts = Dir.glob(@root.join("app/views/layouts/*.html.erb"))

    layouts.each do |layout_path|
      layout_name = File.basename(layout_path, '.html.erb')
      content = File.read(layout_path)

      # yield :javascripts の確認
      if content.include?('<%= yield :javascripts %>')
        puts "  ✅ #{layout_name}.html.erb: <%= yield :javascripts %> が存在します"
      else
        @errors << "#{layout_name}.html.erb: <%= yield :javascripts %> が見つかりません"
      end

      # stylesheet_link_tag の確認
      if content.include?("stylesheet_link_tag")
        puts "  ✅ #{layout_name}.html.erb: stylesheet_link_tag が使われています"
      else
        @warnings << "#{layout_name}.html.erb: stylesheet_link_tag が見つかりません"
      end
    end
    puts
  end

  def check_manifest
    puts "📋 manifest.js をチェック中..."

    manifest_path = @root.join("app/assets/config/manifest.js")

    if manifest_path.exist?
      content = File.read(manifest_path)

      if content.include?('link_tree ../javascripts')
        puts "  ✅ link_tree ../javascripts が存在します"
      else
        @errors << "manifest.js に link_tree ../javascripts がありません"
      end

      if content.include?('link_tree ../stylesheets')
        puts "  ✅ link_tree ../stylesheets が存在します"
      else
        @errors << "manifest.js に link_tree ../stylesheets がありません"
      end
    else
      @errors << "app/assets/config/manifest.js が見つかりません"
    end
    puts
  end

  def check_compiled_assets
    puts "🔨 コンパイル済みアセットをチェック中..."

    public_assets = @root.join("public/assets")

    if public_assets.exist?
      # JavaScript
      js_files = Dir.glob(public_assets.join("#{feature_name}*.js"))
      if js_files.any?
        puts "  ✅ コンパイル済みJSファイルが見つかりました:"
        js_files.each { |f| puts "     - #{File.basename(f)}" }
      else
        @warnings << "コンパイル済みの #{feature_name}.js が見つかりません（rails assets:precompile を実行してください）"
      end

      # CSS
      css_files = Dir.glob(public_assets.join("**/*#{feature_name}*.css"))
      if css_files.any?
        puts "  ✅ コンパイル済みCSSファイルが見つかりました:"
        css_files.each { |f| puts "     - #{f.sub(public_assets.to_s + '/', '')}" }
      else
        @warnings << "コンパイル済みの #{feature_name}.css が見つかりません（rails assets:precompile を実行してください）"
      end
    else
      @warnings << "public/assets/ ディレクトリが見つかりません（rails assets:precompile を実行してください）"
    end
    puts
  end

  def check_routes
    puts "🛤️  ルートをチェック中..."

    routes_path = @root.join("config/routes.rb")

    if routes_path.exist?
      content = File.read(routes_path)

      # feature_name に関連するルートがあるか確認
      if content.match?(/#{feature_name}/i)
        puts "  ✅ routes.rb に #{feature_name} 関連のルートが見つかりました"
      else
        @warnings << "routes.rb に #{feature_name} 関連のルートが見つかりません"
      end
    end
    puts
  end

  def check_content_for_in_views(name, block_name)
    views = Dir.glob(@root.join("app/views/**/*.html.erb"))

    found = false
    views.each do |view_path|
      content = File.read(view_path)
      if content.include?("content_for :#{block_name}") && content.include?(name)
        puts "  ✅ #{view_path.sub(@root.to_s + '/', '')} で content_for :#{block_name} が使われています"
        found = true
      end
    end

    unless found
      @warnings << "どのビューでも content_for :#{block_name} で #{name} を読み込んでいません"
    end
  end

  def check_stylesheet_link_in_layouts(name)
    layouts = Dir.glob(@root.join("app/views/layouts/*.html.erb"))

    found = false
    layouts.each do |layout_path|
      content = File.read(layout_path)
      if content.include?("stylesheet_link_tag") && content.match?(/#{name}/)
        layout_name = File.basename(layout_path, '.html.erb')
        puts "  ✅ #{layout_name}.html.erb で stylesheet_link_tag が使われています"
        found = true
      end
    end

    unless found
      @warnings << "どのレイアウトでも stylesheet_link_tag で #{name} を読み込んでいません"
    end
  end

  def print_results
    puts "=" * 80
    puts "検証結果"
    puts "=" * 80

    if @errors.any?
      puts
      puts "❌ エラー (#{@errors.size}件):"
      @errors.each_with_index do |error, i|
        puts "  #{i + 1}. #{error}"
      end
    end

    if @warnings.any?
      puts
      puts "⚠️  警告 (#{@warnings.size}件):"
      @warnings.each_with_index do |warning, i|
        puts "  #{i + 1}. #{warning}"
      end
    end

    if @errors.empty? && @warnings.empty?
      puts
      puts "✅ 全てのチェックが通過しました！"
    end

    puts
    puts "=" * 80

    if @errors.any?
      puts "❌ 検証失敗: エラーを修正してください"
      exit 1
    elsif @warnings.any?
      puts "⚠️  検証完了: 警告がありますが、動作に問題ない可能性があります"
      exit 0
    else
      puts "✅ 検証成功: 全てのチェックが通過しました"
      exit 0
    end
  end
end

# コマンドラインオプション解析
options = {}
OptionParser.new do |opts|
  opts.banner = "使い方: ruby scripts/validate_feature.rb [オプション]"

  opts.on("-f", "--feature FEATURE", "検証する機能名（例: crop_palette）") do |f|
    options[:feature] = f
  end

  opts.on("-h", "--help", "ヘルプを表示") do
    puts opts
    exit
  end
end.parse!

if options[:feature].nil?
  puts "エラー: --feature オプションが必要です"
  puts "使い方: ruby scripts/validate_feature.rb --feature crop_palette"
  exit 1
end

# 検証実行
validator = FeatureValidator.new(options[:feature])
validator.validate!
