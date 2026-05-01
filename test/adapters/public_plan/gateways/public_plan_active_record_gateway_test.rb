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

          entity = @gateway.find_farm(farm.id)

          assert_not_nil entity
          assert_equal farm.id, entity.id
          assert_equal farm.name, entity.name
        end

        test "find_farm returns nil when missing" do
          assert_nil @gateway.find_farm(999_999_999)
        end

        test "find_farm_size resolves by id string" do
          size = @gateway.find_farm_size("home_garden")

          assert_equal "home_garden", size[:id]
          assert_equal 30, size[:area_sqm]
        end

        test "find_farm_size resolves by area integer" do
          size = @gateway.find_farm_size(300)

          assert_equal "rental_farm", size[:id]
        end

        test "find_crops returns entities for ids" do
          c1 = create(:crop, :reference)
          c2 = create(:crop, :reference)

          entities = @gateway.find_crops([ c1.id, c2.id ])

          assert_equal 2, entities.size
          ids = entities.map(&:id).sort
          assert_equal [ c1.id, c2.id ].sort, ids
        end
      end
    end
  end
end
