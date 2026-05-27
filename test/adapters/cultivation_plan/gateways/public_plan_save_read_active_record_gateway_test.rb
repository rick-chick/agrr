# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSaveReadActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PublicPlanSaveReadActiveRecordGateway.new
          @farm = ::Farm.reference.first || ::Farm.create!(
            user: User.anonymous_user,
            name: "Ref",
            latitude: 35.0,
            longitude: 139.0,
            is_reference: true,
            region: "jp"
          )
          @plan = ::CultivationPlan.create!(
            farm: @farm,
            user: nil,
            total_area: 10.0,
            plan_type: "public",
            plan_year: Date.current.year,
            plan_name: "ReadGwTest",
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year,
            status: "completed"
          )
          ::CultivationPlanField.create!(
            cultivation_plan: @plan,
            name: "F1",
            area: 5.0,
            daily_fixed_cost: 0
          )
          @ref_crop = ::Crop.create!(
            user: nil,
            name: "ReadGwCrop",
            variety: "v",
            is_reference: true,
            area_per_unit: 0.2,
            revenue_per_area: 100.0,
            region: "jp"
          )
          @cpc = ::CultivationPlanCrop.create!(
            cultivation_plan: @plan,
            crop: @ref_crop,
            name: @ref_crop.name,
            variety: @ref_crop.variety,
            area_per_unit: @ref_crop.area_per_unit,
            revenue_per_area: @ref_crop.revenue_per_area
          )
        end

        test "find_header returns snapshot for existing plan" do
          header = @gateway.find_header(plan_id: @plan.id)
          assert_equal @plan.id, header.plan_id
          assert_equal @farm.id, header.farm_id
        end

        test "find_header returns nil for missing plan" do
          assert_nil @gateway.find_header(plan_id: -1)
        end

        test "list_field_rows returns field datums" do
          rows = @gateway.list_field_rows(plan_id: @plan.id)
          assert_equal 1, rows.size
          assert_equal "F1", rows.first.name
        end

        test "list_crop_reference_rows returns crop reference snapshots" do
          rows = @gateway.list_crop_reference_rows(plan_id: @plan.id)
          assert_equal 1, rows.size
          row = rows.first
          assert_equal @cpc.id, row.cultivation_plan_crop_id
          assert_equal @ref_crop.id, row.reference_crop_id
          assert_equal "ReadGwCrop", row.name
        end

        test "list_pest_reference_rows returns pest snapshots with linked crop ids" do
          ref_pest = ::Pest.create!(
            user: nil,
            name: "ReadGwPest",
            is_reference: true,
            region: "jp"
          )
          CropPest.create!(crop: @ref_crop, pest: ref_pest)

          rows = @gateway.list_pest_reference_rows(plan_id: @plan.id, region: "jp")
          row = rows.find { |r| r.reference_pest_id == ref_pest.id }
          assert_not_nil row
          assert_equal "ReadGwPest", row.name
          assert_includes row.linked_reference_crop_ids, @ref_crop.id
        end

        test "list_pesticide_reference_rows returns reference pesticides with nested rows" do
          ref_pest = ::Pest.create!(
            user: nil,
            name: "ReadGwPzPest#{SecureRandom.hex(4)}",
            is_reference: true,
            region: "jp"
          )
          ref_pesticide = ::Pesticide.create!(
            user: nil,
            crop: @ref_crop,
            pest: ref_pest,
            name: "ReadGwPz#{SecureRandom.hex(4)}",
            active_ingredient: "AI",
            is_reference: true,
            region: "jp"
          )
          ref_pesticide.create_pesticide_usage_constraint!(
            min_temperature: 5.0,
            max_temperature: 35.0,
            max_application_count: 2
          )
          ref_pesticide.create_pesticide_application_detail!(
            dilution_ratio: "500倍",
            amount_per_m2: 2.0,
            amount_unit: "g",
            application_method: "灌注"
          )
          us_only = ::Pesticide.create!(
            user: nil,
            crop: @ref_crop,
            pest: ref_pest,
            name: "ReadGwPzUs#{SecureRandom.hex(4)}",
            is_reference: true,
            region: "us"
          )

          rows = @gateway.list_pesticide_reference_rows(region: "jp")
          row = rows.find { |r| r.reference_pesticide_id == ref_pesticide.id }
          assert_not_nil row
          assert_equal ref_pesticide.name, row.name
          assert_equal @ref_crop.id, row.reference_crop_id
          assert_equal ref_pest.id, row.reference_pest_id
          assert_equal "AI", row.active_ingredient
          assert_not_nil row.usage_constraint
          assert_equal 5.0, row.usage_constraint.min_temperature
          assert_not_nil row.application_detail
          assert_equal "500倍", row.application_detail.dilution_ratio
          assert_nil rows.find { |r| r.reference_pesticide_id == us_only.id }
        end

        test "list_fertilize_reference_rows returns reference fertilizes for region" do
          ref_f = ::Fertilize.create!(
            user: nil,
            name: "ReadGwFert#{SecureRandom.hex(4)}",
            n: 1,
            p: 2,
            k: 3,
            is_reference: true,
            region: "jp"
          )
          us_only = ::Fertilize.create!(
            user: nil,
            name: "ReadGwFertUs#{SecureRandom.hex(4)}",
            n: 1,
            p: 1,
            k: 1,
            is_reference: true,
            region: "us"
          )

          rows = @gateway.list_fertilize_reference_rows(region: "jp")
          row = rows.find { |r| r.reference_fertilize_id == ref_f.id }
          assert_not_nil row
          assert_equal ref_f.name, row.name
          assert_equal ref_f.n, row.n
          assert_nil rows.find { |r| r.reference_fertilize_id == us_only.id }
        end

        test "exists_fertilize_name? reflects global name uniqueness" do
          name = "ReadGwFertExists#{SecureRandom.hex(4)}"
          assert_not @gateway.exists_fertilize_name?(name: name)

          ::Fertilize.create!(
            user: nil,
            name: name,
            is_reference: true,
            region: "jp"
          )

          assert @gateway.exists_fertilize_name?(name: name)
        end
      end
    end
  end
end
