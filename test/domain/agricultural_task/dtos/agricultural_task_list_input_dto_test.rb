# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskListInputDtoTest < ActiveSupport::TestCase
        test "non-admin with any param normalizes to user" do
          dto = AgriculturalTaskListInputDto.new(is_admin: false, filter: "reference")
          assert_equal "user", dto.filter

          dto_all = AgriculturalTaskListInputDto.new(is_admin: false, filter: "all")
          assert_equal "user", dto_all.filter

          dto_invalid = AgriculturalTaskListInputDto.new(is_admin: false, filter: "bogus")
          assert_equal "user", dto_invalid.filter
        end

        test "admin with nil normalizes to all" do
          dto = AgriculturalTaskListInputDto.new(is_admin: true, filter: nil)
          assert_equal "all", dto.filter
        end

        test "admin with reference keeps reference" do
          dto = AgriculturalTaskListInputDto.new(is_admin: true, filter: "reference")
          assert_equal "reference", dto.filter
        end

        test "admin with invalid normalizes to all" do
          dto = AgriculturalTaskListInputDto.new(is_admin: true, filter: "bogus")
          assert_equal "all", dto.filter
        end

        test "admin with user keeps user" do
          dto = AgriculturalTaskListInputDto.new(is_admin: true, filter: "user")
          assert_equal "user", dto.filter
        end
      end
    end
  end
end
