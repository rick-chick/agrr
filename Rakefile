# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

# Custom test tasks
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