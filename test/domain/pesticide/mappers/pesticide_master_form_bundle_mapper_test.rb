# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Mappers
      class PesticideMasterFormBundleMapperTest < DomainLibTestCase
        test "from_parts assembles bundle DTO" do
          snapshot = Domain::Pesticide::Dtos::PesticideMasterFormSnapshot.new(
            id: nil,
            new_record: true,
            name: "n"
          )
          crop_row = Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow.new(id: 1, name: "C")
          pest_row = Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow.new(id: 2, name: "P")

          bundle = PesticideMasterFormBundleMapper.from_parts(
            pesticide_master_form_snapshot: snapshot,
            crop_pick_rows: [ crop_row ],
            pest_pick_rows: [ pest_row ]
          )

          assert_same snapshot, bundle.pesticide_master_form_snapshot
          assert_equal [ crop_row ], bundle.crop_pick_rows
          assert_equal [ pest_row ], bundle.pest_pick_rows
        end
      end
    end
  end
end
