# frozen_string_literal: true

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# Rails.application.config.active_storage.variant_processor = :mini_magick

# Configure Active Storage to use the appropriate service based on environment
# production は production.rb で AWS_S3_BUCKET により :amazon_env / :local を設定済み
Rails.application.configure do
  case Rails.env
  when 'development', 'docker'
    config.active_storage.service = :local
  when 'test'
    config.active_storage.service = :test
  end
end
