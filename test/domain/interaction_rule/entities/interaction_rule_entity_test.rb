# frozen_string_literal: true

require "test_helper"

module Domain
  module InteractionRule
    module Entities
      class InteractionRuleEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = InteractionRuleEntity.new(
            id: 1,
            user_id: 123,
            rule_type: "type1",
            source_group: "group1",
            target_group: "group2",
            impact_ratio: 0.5,
            is_directional: true,
            description: "Test rule",
            region: "jp",
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert_equal 1, entity.id
          assert_equal 123, entity.user_id
          assert_equal "type1", entity.rule_type
          assert_equal "group1", entity.source_group
          assert_equal "group2", entity.target_group
          assert_equal 0.5, entity.impact_ratio
          assert_equal true, entity.is_directional
          assert_equal "Test rule", entity.description
          assert_equal "jp", entity.region
          assert_equal false, entity.is_reference
        end

        test "should initialize with nil region" do
          entity = InteractionRuleEntity.new(
            id: 1,
            user_id: 123,
            rule_type: "type1",
            source_group: "group1",
            target_group: "group2",
            impact_ratio: 0.5,
            is_directional: true,
            description: "Test rule",
            region: nil,
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert_nil entity.region
        end

        test "should raise error when required attributes are blank" do
          assert_raises(ArgumentError, "rule_type, source_group, target_group, impact_ratio are required") do
            InteractionRuleEntity.new(
              id: 1,
              user_id: 123,
              rule_type: "",
              source_group: "group1",
              target_group: "group2",
              impact_ratio: 0.5,
              is_directional: true,
              description: "Test rule",
              region: "jp",
              is_reference: false,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when region is invalid" do
          assert_raises(ArgumentError, "region must be one of jp, us, in") do
            InteractionRuleEntity.new(
              id: 1,
              user_id: 123,
              rule_type: "type1",
              source_group: "group1",
              target_group: "group2",
              impact_ratio: 0.5,
              is_directional: true,
              description: "Test rule",
              region: "invalid",
              is_reference: false,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should accept valid region values" do
          %w[jp us in].each do |valid_region|
            entity = InteractionRuleEntity.new(
              id: 1,
              user_id: 123,
              rule_type: "type1",
              source_group: "group1",
              target_group: "group2",
              impact_ratio: 0.5,
              is_directional: true,
              description: "Test rule",
              region: valid_region,
              is_reference: false,
              created_at: Time.current,
              updated_at: Time.current
            )
            assert_equal valid_region, entity.region
          end
        end

        test "reference? returns expected value" do
          entity = InteractionRuleEntity.new(
            id: 1,
            user_id: 123,
            rule_type: "type1",
            source_group: "group1",
            target_group: "group2",
            impact_ratio: 0.5,
            is_directional: true,
            description: "Test rule",
            region: "jp",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert entity.reference?
        end

        test "to_hash returns expected hash" do
          created_at = Time.current
          updated_at = Time.current
          entity = InteractionRuleEntity.new(
            id: 1,
            user_id: 123,
            rule_type: "type1",
            source_group: "group1",
            target_group: "group2",
            impact_ratio: 0.5,
            is_directional: true,
            description: "Test rule",
            region: "jp",
            is_reference: false,
            created_at: created_at,
            updated_at: updated_at
          )
          expected_hash = {
            id: 1,
            user_id: 123,
            rule_type: "type1",
            source_group: "group1",
            target_group: "group2",
            impact_ratio: 0.5,
            is_directional: true,
            description: "Test rule",
            region: "jp",
            is_reference: false,
            created_at: created_at,
            updated_at: updated_at
          }
          assert_equal expected_hash, entity.to_hash
        end
      end
    end
  end
end