# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveFieldCreateAttributesMapperTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        test "attributes_for_create adds description from coordinates" do
          datum = Dtos::PublicPlanSaveFieldDatum.new(
            name: "区画A",
            area: 12.5,
            coordinates: [ 35.0, 139.0 ]
          )

          attrs = PlanSaveFieldCreateAttributesMapper.attributes_for_create(
            datum: datum,
            translator: build_translator
          )

          assert_equal "区画A", attrs[:name]
          assert_in_delta 12.5, attrs[:area].to_f, 0.001
          assert_equal "services.plan_save_service.messages.coordinates|{:lat=>35.0, :lng=>139.0}", attrs[:description]
        end

        test "attributes_for_create omits description without coordinates" do
          datum = Dtos::PublicPlanSaveFieldDatum.new(name: "区画B", area: 3.0, coordinates: [])

          attrs = PlanSaveFieldCreateAttributesMapper.attributes_for_create(
            datum: datum,
            translator: build_translator
          )

          assert_nil attrs[:description]
        end
      end
    end
  end
end
