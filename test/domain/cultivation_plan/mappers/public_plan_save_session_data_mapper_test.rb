# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PublicPlanSaveSessionDataMapperTest < DomainLibTestCase
        test "from_snapshots builds session dto from header and field rows" do
          header = Dtos::PublicPlanSaveHeaderSnapshot.new(
            plan_id: 99,
            farm_id: 7,
            crop_ids: [ 1, 2 ]
          )
          field_rows = [
            Dtos::PublicPlanSaveFieldDatum.new(
              name: "F1",
              area: 5.0,
              coordinates: [ 35.0, 139.0 ]
            )
          ]

          dto = PublicPlanSaveSessionDataMapper.from_snapshots(
            header: header,
            field_rows: field_rows
          )

          assert_equal 99, dto.plan_id
          assert_equal 7, dto.farm_id
          assert_equal [ 1, 2 ], dto.crop_ids
          assert_equal 1, dto.field_data.size
          assert_equal "F1", dto.field_data.first.name
        end
      end
    end
  end
end
