# frozen_string_literal: true

require "test_helper"

module Adapters
  module InteractionRule
    module Mappers
      class InteractionRuleAgrrMapperTest < ActiveSupport::TestCase
        test "to_agrr_format builds rule hash from record" do
          rule = create(:interaction_rule, :reference)
          result = InteractionRuleAgrrMapper.to_agrr_format(rule)
          assert_equal "rule_#{rule.id}", result["rule_id"]
          assert_equal rule.rule_type, result["rule_type"]
        end
      end
    end
  end
end
