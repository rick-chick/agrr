# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanSavePesticideAttributesMapperTest < DomainLibTestCase
        def build_row(with_constraint: false, with_detail: false)
          usage_constraint = if with_constraint
                               Dtos::PublicPlanSavePesticideUsageConstraintRow.new(
                                 min_temperature: 5.0,
                                 max_temperature: 35.0,
                                 max_application_count: 2
                               )
                             end
          application_detail = if with_detail
                                 Dtos::PublicPlanSavePesticideApplicationDetailRow.new(
                                   dilution_ratio: "1000倍",
                                   amount_per_m2: 0.5,
                                   amount_unit: "g",
                                   application_method: "散布"
                                 )
                               end

          Dtos::PublicPlanSavePesticideReferenceRow.new(
            reference_pesticide_id: 300,
            reference_crop_id: 10,
            reference_pest_id: 20,
            name: "農薬A",
            active_ingredient: "成分",
            description: "説明",
            region: nil,
            usage_constraint: usage_constraint,
            application_detail: application_detail
          )
        end

        test "attributes_for_create uses row region when present" do
          row = build_row
          row_with_region = Dtos::PublicPlanSavePesticideReferenceRow.new(
            reference_pesticide_id: row.reference_pesticide_id,
            reference_crop_id: row.reference_crop_id,
            reference_pest_id: row.reference_pest_id,
            name: row.name,
            active_ingredient: row.active_ingredient,
            description: row.description,
            region: "us",
            usage_constraint: nil,
            application_detail: nil
          )

          attrs = PlanSavePesticideAttributesMapper.attributes_for_create(
            row: row_with_region,
            region: "jp",
            user_crop_id: 101,
            user_pest_id: 201
          )

          assert_equal "us", attrs[:region]
        end

        test "attributes_for_create resolves region from farm when row region is nil" do
          row = build_row

          attrs = PlanSavePesticideAttributesMapper.attributes_for_create(
            row: row,
            region: "jp",
            user_crop_id: 101,
            user_pest_id: 201
          )

          assert_equal 101, attrs[:crop_id]
          assert_equal 201, attrs[:pest_id]
          assert_equal "農薬A", attrs[:name]
          assert_equal "成分", attrs[:active_ingredient]
          assert_equal "説明", attrs[:description]
          assert_equal "jp", attrs[:region]
          assert_equal false, attrs[:is_reference]
          assert_equal 300, attrs[:source_pesticide_id]
        end

        test "usage_constraint_attributes returns nil when row has no constraint" do
          assert_nil PlanSavePesticideAttributesMapper.usage_constraint_attributes(row: build_row)
        end

        test "usage_constraint_attributes maps nested row fields" do
          row = build_row(with_constraint: true)

          attrs = PlanSavePesticideAttributesMapper.usage_constraint_attributes(row: row)

          assert_equal 5.0, attrs[:min_temperature]
          assert_equal 35.0, attrs[:max_temperature]
          assert_equal 2, attrs[:max_application_count]
        end

        test "application_detail_attributes returns nil when row has no detail" do
          assert_nil PlanSavePesticideAttributesMapper.application_detail_attributes(row: build_row)
        end

        test "application_detail_attributes maps nested row fields" do
          row = build_row(with_detail: true)

          attrs = PlanSavePesticideAttributesMapper.application_detail_attributes(row: row)

          assert_equal "1000倍", attrs[:dilution_ratio]
          assert_in_delta 0.5, attrs[:amount_per_m2].to_f, 0.001
          assert_equal "g", attrs[:amount_unit]
          assert_equal "散布", attrs[:application_method]
        end
      end
    end
  end
end
