# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Shared
    module Mappers
      class LocaleToRegionMapperTest < DomainLibTestCase
        test "maps known locales" do
          assert_equal "jp", LocaleToRegionMapper.call(:ja)
          assert_equal "us", LocaleToRegionMapper.call(:us)
          assert_equal "in", LocaleToRegionMapper.call(:in)
        end

        test "defaults unknown locale to jp" do
          assert_equal "jp", LocaleToRegionMapper.call(:unknown)
        end
      end
    end
  end
end
