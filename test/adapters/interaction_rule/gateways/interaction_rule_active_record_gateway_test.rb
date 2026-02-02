# frozen_string_literal: true

require "test_helper"

module Adapters
  module InteractionRule
    module Gateways
      class InteractionRuleActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = InteractionRuleActiveRecordGateway.new
        end

        test "should find by id and return entity" do
          record = create(:interaction_rule, :reference, rule_type: "continuous_cultivation", region: "jp")
          entity = @gateway.find_by_id(record.id)
          assert_not_nil entity
          assert_equal record.id, entity.id
          assert_equal "continuous_cultivation", entity.rule_type
          assert_equal "jp", entity.region
        end

        test "should raise when not found" do
          assert_raises(StandardError) { @gateway.find_by_id(9999) }
        end

        test "should create and return entity" do
          create_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInputDto.new(
            rule_type: "continuous_cultivation",
            source_group: "ナス科",
            target_group: "ナス科",
            impact_ratio: 0.7,
            region: "us",
            is_reference: true
          )
          entity = @gateway.create(create_dto)
          assert_not_nil entity
          assert_equal "continuous_cultivation", entity.rule_type
          assert_equal "us", entity.region
          assert entity.reference?
          persisted = ::InteractionRule.find_by(rule_type: "continuous_cultivation", region: "us")
          assert_not_nil persisted
        end

        test "should raise when create fails validation - invalid region" do
          create_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInputDto.new(
            rule_type: "continuous_cultivation",
            source_group: "ナス科",
            target_group: "ナス科",
            impact_ratio: 0.7,
            region: "invalid",
            is_reference: true
          )
          assert_raises(StandardError) { @gateway.create(create_dto) }
        end

        test "should update and return entity" do
          record = create(:interaction_rule, :reference, rule_type: "continuous_cultivation", region: "jp")
          update_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInputDto.new(
            id: record.id,
            region: "us"
          )
          entity = @gateway.update(record.id, update_dto)
          assert_not_nil entity
          assert_equal record.id, entity.id
          assert_equal "us", entity.region
          assert_equal "continuous_cultivation", entity.rule_type # unchanged
          record.reload
          assert_equal "us", record.region
        end

        test "should raise when update fails validation - invalid region" do
          record = create(:interaction_rule, :reference, region: "jp")
          update_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInputDto.new(
            id: record.id,
            region: "invalid"
          )
          assert_raises(StandardError) { @gateway.update(record.id, update_dto) }
        end

        test "should destroy existing record" do
          record = create(:interaction_rule, :reference)
          @gateway.destroy(record.id)
          assert_nil ::InteractionRule.find_by(id: record.id)
        end

        test "should raise when destroy not found" do
          assert_raises(StandardError) { @gateway.destroy(9999) }
        end

        test "should list all records and return entities" do
          record1 = create(:interaction_rule, :reference, region: "jp")
          record2 = create(:interaction_rule, :reference, region: "us")
          entities = @gateway.list
          assert_equal 2, entities.size
          assert entities.all? { |e| e.is_a?(Domain::InteractionRule::Entities::InteractionRuleEntity) }
          ids = entities.map(&:id)
          assert_includes ids, record1.id
          assert_includes ids, record2.id
        end

        test "should list with scope and return entities" do
          record1 = create(:interaction_rule, :reference, region: "jp")
          record2 = create(:interaction_rule, :reference, region: "us")
          scope = ::InteractionRule.where(region: "jp")
          entities = @gateway.list(scope)
          assert_equal 1, entities.size
          assert_equal record1.id, entities.first.id
          assert entities.all? { |e| e.is_a?(Domain::InteractionRule::Entities::InteractionRuleEntity) }
        end
      end
    end
  end
end