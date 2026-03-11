# frozen_string_literal: true

# GCP Cloud Run では AWS に接続しない（K_SERVICE は Cloud Run が自動設定）
unless ENV['K_SERVICE'].present?
  # AWS configuration for S3
  if Rails.env.production? || Rails.env.aws_test?
    begin
      require 'aws-sdk-s3'

      # Only configure if credentials are provided
      if ENV['AWS_ACCESS_KEY_ID'].present? && ENV['AWS_SECRET_ACCESS_KEY'].present?
        Aws.config.update({
          region: ENV.fetch('AWS_REGION', 'ap-northeast-1'),
          credentials: Aws::Credentials.new(
            ENV['AWS_ACCESS_KEY_ID'],
            ENV['AWS_SECRET_ACCESS_KEY']
          )
        })
      end
    rescue LoadError
      # AWS SDK not available, skip configuration
      Rails.logger.warn "AWS SDK not loaded, skipping AWS configuration" if defined?(Rails.logger)
    end
  end
end
