# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
#
# テスト実行方法:
#   - 全テスト: docker compose run --rm test bundle exec rails test
#   - システムテスト: docker compose run --rm test bundle exec rails test:system
#   - 特定テスト: docker compose run --rm test bundle exec rails test test/models/farm_test.rb
# 詳細は README.md および docs/TESTING_GUIDELINES.md を参照
#
# ⚠️ IMPORTANT: Testing guidelines must be followed
# See: docs/TESTING_GUIDELINES.md

require_relative "config/application"

Rails.application.load_tasks

# Custom test tasks
# ⚠️ IMPORTANT: When writing tests, refer to docs/TESTING_GUIDELINES.md
namespace :test do
  desc "Run all tests (unit, integration, and system)"
  task all: :environment do
    puts "Running all tests..."
    Rake::Task["test"].invoke
    Rake::Task["test:system"].invoke if defined?(Capybara)
  end

  desc "Run tests with coverage"
  task coverage: :environment do
    ENV["COVERAGE"] = "true"
    Rake::Task["test:all"].invoke
  end
end