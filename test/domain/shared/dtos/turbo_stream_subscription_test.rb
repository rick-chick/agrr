# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Shared
    module Dtos
      class TurboStreamSubscriptionTest < DomainLibTestCase
        test "for_farm builds streamables matching legacy Farm class subscription" do
          subscription = TurboStreamSubscription.for_farm(42)

          assert_equal ["Farm", 42], subscription.streamables
        end

        test "initialize rejects blank streamables" do
          assert_raises(ArgumentError) { TurboStreamSubscription.new(streamables: []) }
        end
      end
    end
  end
end
