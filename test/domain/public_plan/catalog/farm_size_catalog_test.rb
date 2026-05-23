# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module PublicPlan
    module Catalog
      class FarmSizeCatalogTest < DomainLibTestCase
        test "all returns three farm sizes" do
          sizes = FarmSizeCatalog.all
          assert_equal 3, sizes.length
          assert_equal "home_garden", sizes[0][:id]
          assert_equal 30, sizes[0][:area_sqm]
        end

        test "find_by_id matches id string" do
          size = FarmSizeCatalog.find_by_id("rental_farm")
          assert_equal 300, size[:area_sqm]
        end

        test "find_by_id matches area_sqm integer" do
          size = FarmSizeCatalog.find_by_id(50)
          assert_equal "community_garden", size[:id]
        end
      end
    end
  end
end
