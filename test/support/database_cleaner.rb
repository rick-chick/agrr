# frozen_string_literal: true

require "database_cleaner/active_record"

DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner.allow_production = false

module DatabaseCleanerSetup
  def before_setup
    if defined?(ContractTestCase) && is_a?(ContractTestCase)
      DatabaseCleaner[:active_record].strategy = :truncation
    else
      DatabaseCleaner[:active_record].strategy = :transaction
    end
    DatabaseCleaner[:active_record].start
    super
  end

  def after_teardown
    super
    DatabaseCleaner[:active_record].clean
  end
end

class ActiveSupport::TestCase
  include DatabaseCleanerSetup
end

class ActionDispatch::IntegrationTest
  include DatabaseCleanerSetup
end
