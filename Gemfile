# frozen_string_literal: true

# P8.5: Rails remains only as the R4 contract harness (ActiveRecord fixtures + Minitest).
# API / WS / OAuth run on agrr-server (Rust).
source "https://rubygems.org"

ruby "3.3.10"

gem "rails", "~> 8.0.0"
gem "sqlite3", ">= 2.1"
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri mswin mswin64 mingw x64_mingw]
end

group :test do
  gem "simplecov", "= 0.22.0", require: false
  gem "database_cleaner-active_record", "= 2.2.2"
  gem "factory_bot_rails", "= 6.5.1"
  gem "mocha", "= 2.7.1"
end
