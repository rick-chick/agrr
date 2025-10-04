# frozen_string_literal: true

# AWS configuration for S3
if Rails.env.production?
  Aws.config.update({
    region: ENV.fetch('AWS_REGION', 'ap-northeast-1'),
    credentials: Aws::Credentials.new(
      ENV['AWS_ACCESS_KEY_ID'],
      ENV['AWS_SECRET_ACCESS_KEY']
    )
  })
end
