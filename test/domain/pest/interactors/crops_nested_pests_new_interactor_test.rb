# frozen_string_literal: true

require "test_helper"

class Domain::Pest::Interactors::CropsNestedPestsNewInteractorTest < ActiveSupport::TestCase
  test "on_success passes blank DTO snapshot and unassociated pest entities" do
    user = Domain::Shared::Dtos::UserDto.new(id: 7, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(7).returns(user)

    e1 = mock
    e1.stubs(:id).returns(10)
    e2 = mock
    e2.stubs(:id).returns(20)

    pest_gateway = mock
    pest_gateway.expects(:list_selectable_pest_entities_recent_first).with(user).returns([ e1, e2 ])
    pest_gateway.expects(:pest_ids_linked_to_crop).with(crop_id: 5).returns([ 10 ])

    output = mock
    output.expects(:on_success).with do |pest_crop_nest_snapshot:, unassociated_pests:|
      pest_crop_nest_snapshot.is_a?(Domain::Pest::Dtos::PestCropNestSnapshotDto) &&
        pest_crop_nest_snapshot.id.nil? &&
        pest_crop_nest_snapshot.user_id == 7 &&
        unassociated_pests == [ e2 ]
    end

    Domain::Pest::Interactors::CropsNestedPestsNewInteractor.new(
      output_port: output,
      user_id: 7,
      user_lookup: user_lookup,
      pest_gateway: pest_gateway
    ).call(crop_id: 5)
  end
end
