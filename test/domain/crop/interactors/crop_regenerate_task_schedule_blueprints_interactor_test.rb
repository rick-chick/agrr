# frozen_string_literal: true

require "test_helper"

class CropRegenerateTaskScheduleBlueprintsInteractorTest < ActiveSupport::TestCase
  test "on_success when regenerator succeeds" do
    user = Domain::Shared::Dtos::UserDto.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop = mock
    gateway = mock
    gateway.expects(:find_authorized_model_for_edit).with(user, 9).returns(crop)

    regeneration_gateway = mock
    regeneration_gateway.expects(:regenerate_from_crop!).with(crop: crop)

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
    user = Domain::Shared::Dtos::UserDto.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop = mock
    gateway = mock
    gateway.expects(:find_authorized_model_for_edit).with(user, 9).returns(crop)

    regeneration_gateway = mock
    regeneration_gateway.expects(:regenerate_from_crop!).raises(Domain::Crop::Exceptions::BlueprintRegenerationFromAgrrFailed.new("x"))

    output = mock
    output.expects(:on_failure).with do |dto|
      assert_instance_of Domain::Shared::Dtos::ErrorDto, dto
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
