# frozen_string_literal: true

require "database_cleaner/active_record"

# DatabaseCleanerの設定
DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner.allow_production = false

# Minitest hooks
module DatabaseCleanerSetup
  def before_setup
    # SystemTestCaseの場合はtruncationを使用（既にApplicationSystemTestCaseで設定済み）
    if self.class < ActionDispatch::SystemTestCase
      return super
    end
    
    # 通常のテストではtransactionを使用
    DatabaseCleaner[:active_record].strategy = :transaction
    DatabaseCleaner[:active_record].start
    super
  end

  def after_teardown
    super
    # SystemTestCaseの場合はApplicationSystemTestCaseでクリーンアップ
    unless self.class < ActionDispatch::SystemTestCase
      DatabaseCleaner[:active_record].clean
    end
  end
end

# すべてのテストケースにDatabaseCleanerを適用
# （SystemTestCaseは独自の設定を持つため除外）
class ActiveSupport::TestCase
  include DatabaseCleanerSetup
end

