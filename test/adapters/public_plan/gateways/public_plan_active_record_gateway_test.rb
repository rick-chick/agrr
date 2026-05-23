# frozen_string_literal: true

require "test_helper"

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = PublicPlanActiveRecordGateway.new
        end

        test "find_farm returns farm entity when record exists" do
          farm = create(:farm, :reference)

          entity = @gateway.find_by_farm_id(farm.id)

          assert_not_nil entity
          assert_equal farm.id, entity.id
          assert_equal farm.name, entity.name
        end

        test "find_farm returns nil when missing" do
          assert_nil @gateway.find_by_farm_id(999_999_999)
        end

        test "list_farm_sizes returns catalog entries" do
          sizes = @gateway.list_farm_sizes
          assert_equal 3, sizes.size
          assert_equal "home_garden", sizes.first[:id]
        end

        test "find_by_farm_size_id resolves by id string" do
          size = @gateway.find_by_farm_size_id("home_garden")

          assert_equal "home_garden", size[:id]
          assert_equal 30, size[:area_sqm]
        end

        test "find_by_farm_size_id resolves by area integer" do
          size = @gateway.find_by_farm_size_id(300)

          assert_equal "rental_farm", size[:id]
        end

        test "find_crops returns entities for ids" do
          c1 = create(:crop, :reference, region: "jp")
          c2 = create(:crop, :reference, region: "jp")

          entities = @gateway.list_by_ids([ c1.id, c2.id ], "jp")

          assert_equal 2, entities.size
          ids = entities.map(&:id).sort
          assert_equal [ c1.id, c2.id ].sort, ids
        end

        test "find_crops excludes non-reference crops" do
          ref = create(:crop, :reference, region: "jp")
          non = create(:crop, :user_owned, region: "jp")
          entities = @gateway.list_by_ids([ ref.id, non.id ], "jp")
          assert_equal [ ref.id ], entities.map(&:id)
        end

        test "find_crops filters by region when provided" do
          jp = create(:crop, :reference, region: "jp")
          us = create(:crop, :reference, region: "us")
          entities = @gateway.list_by_ids([ jp.id, us.id ], "jp")
          assert_equal [ jp.id ], entities.map(&:id)
        end
      end
    end
  end
end
