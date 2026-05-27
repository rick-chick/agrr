# frozen_string_literal: true

require "domain_lib_test_helper"
require_relative "../../support/lib_domain_active_record_reference_scanner"

class LibDomainNoActiveRecordReferencesTest < DomainLibTestCase
  BARRIER = <<~MSG.strip
    lib/domain の実行可能コードに ActiveRecord または AR モデル定数（::Field 等）を書いてはいけません。
    永続化・クエリは app/adapters の Gateway に閉じ、domain には Entity / DTO / Gateway インターフェースのみ渡してください。
    （ARCHITECTURE.md — lib/domain Prohibited practices: Rails.*, AR クエリ）

    永続化は Gateway、認可は Entity / DTO を受け取る Policy（例: PrivateCultivationPlanAccessPolicy）に閉じる。
  MSG

  test "lib/domain has no ActiveRecord or top-level AR model constant references in executable code" do
    violations = LibDomainActiveRecordReferenceScanner.violations

    assert_empty violations, "#{BARRIER}\n\nViolations:\n#{violations.map { |v| "  - #{v}" }.join("\n")}"
  end
end
