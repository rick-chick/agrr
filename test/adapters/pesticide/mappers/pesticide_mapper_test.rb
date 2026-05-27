# frozen_string_literal: true

require "test_helper"

module Adapters
  module Pesticide
    module Mappers
      class PesticideMapperTest < ActiveSupport::TestCase
        test "pesticide_entity_from_record maps AR-like record to entity" do
          record = mock
          record.stubs(:id).returns(1)
          record.stubs(:user_id).returns(2)
          record.stubs(:name).returns("Test Pesticide")
          record.stubs(:active_ingredient).returns("Test Ingredient")
          record.stubs(:description).returns("Test Description")
          record.stubs(:crop_id).returns(3)
          record.stubs(:pest_id).returns(4)
          record.stubs(:region).returns("jp")
          record.stubs(:is_reference).returns(false)
          record.stubs(:created_at).returns(Time.utc(2026, 1, 1))
          record.stubs(:updated_at).returns(Time.utc(2026, 1, 1))

          entity = PesticideMapper.pesticide_entity_from_record(record)

          assert_equal 1, entity.id
          assert_equal 2, entity.user_id
          assert_equal "Test Pesticide", entity.name
          assert_equal "Test Ingredient", entity.active_ingredient
          assert_equal "Test Description", entity.description
          assert_equal 3, entity.crop_id
          assert_equal 4, entity.pest_id
          assert_equal "jp", entity.region
          assert_equal false, entity.is_reference
        end
      end
    end
  end
end
