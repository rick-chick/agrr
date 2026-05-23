# frozen_string_literal: true

require "domain_lib_test_helper"

class CropRegenerateTaskScheduleBlueprintsInteractorTest < DomainLibTestCase
  test "on_success when regenerator succeeds" do
    user = Domain::Shared::Dtos::User.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop = stub(is_reference: false, user_id: 1)
    gateway = mock
    gateway.expects(:find_by_id).with(9).returns(crop)

    regeneration_gateway = mock
    regeneration_gateway.expects(:regenerate_from_crop!).with(crop_id: 9)

    output = mock
    output.expects(:on_success)

    Domain::Crop::Interactors::CropRegenerateTaskScheduleBlueprintsInteractor.new(
      output_port: output,
      user_id: 1,
      crop_id: 9,
      gateway: gateway,
      blueprint_regeneration_gateway: regeneration_gateway,
      translator: mock,
      logger: mock,
      user_lookup: user_lookup
    ).call
  end

  test "on_failure with blueprint regeneration domain errors uses message" do
    user = Domain::Shared::Dtos::User.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop = stub(is_reference: false, user_id: 1)
    gateway = mock
    gateway.expects(:find_by_id).with(9).returns(crop)

    regeneration_gateway = mock
    regeneration_gateway.expects(:regenerate_from_crop!).raises(Domain::Crop::Exceptions::BlueprintRegenerationFromAgrrFailed.new("x"))

    output = mock
    output.expects(:on_failure).with do |dto|
      assert_instance_of Domain::Shared::Dtos::Error, dto
      assert_equal "x", dto.message
      true
    end

    Domain::Crop::Interactors::CropRegenerateTaskScheduleBlueprintsInteractor.new(
      output_port: output,
      user_id: 1,
      crop_id: 9,
      gateway: gateway,
      blueprint_regeneration_gateway: regeneration_gateway,
      translator: mock,
      logger: mock,
      user_lookup: user_lookup
    ).call
  end
end
