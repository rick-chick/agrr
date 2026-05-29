# frozen_string_literal: true

require "test_helper"
require_relative "../support/adapter_read_gateway_boundary_scanner"

class AdapterReadGatewayBoundaryTest < ActiveSupport::TestCase
  BARRIER = <<~MSG.strip
    Read 系 adapter gateway は Domain::*::Mappers の load_snapshot / from_snapshots / load_plan_rows / assemble を呼ばない。
    組立は Interactor が narrow read gateway を呼び、domain mapper で行う（ARCHITECTURE.md — Read snapshot assembly）。
  MSG

  test "read gateways do not orchestrate via domain mappers" do
    violations = AdapterReadGatewayBoundaryScanner.violations

    assert_empty violations, "#{BARRIER}\n\nViolations:\n#{violations.map { |v| "  - #{v}" }.join("\n")}"
  end
end
