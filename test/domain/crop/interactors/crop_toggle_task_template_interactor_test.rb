# frozen_string_literal: true

require "domain_lib_test_helper"

class CropToggleTaskTemplateInteractorTest < DomainLibTestCase
  test "on_success delegates to toggle gateway" do
    user = Domain::Shared::Dtos::User.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop_entity = stub(is_reference: false, user_id: 1)
    crop_gateway = mock
    crop_gateway.expects(:find_by_id).with(9).returns(crop_entity)

    task_entity = mock
    task_gateway = mock
    task_gateway.expects(:find_by_id).with(44).returns(task_entity)

    result = Domain::Crop::Dtos::CropToggleTaskTemplateSnapshot.new(
      available_agricultural_tasks: [],
      selected_task_ids: [],
      task_schedule_blueprints: []
    )

    toggle_gateway = mock
    toggle_gateway.expects(:toggle_build_snapshot!).with(crop_id: 9, agricultural_task_id: 44).returns(result)

    output = mock
    output.expects(:on_success).with(result)

    Domain::Crop::Interactors::CropToggleTaskTemplateInteractor.new(
      output_port: output,
      user_id: 1,
      crop_id: 9,
      agricultural_task_id: 44,
      gateway: crop_gateway,
      agricultural_task_gateway: task_gateway,
      toggle_gateway: toggle_gateway,
      translator: mock,
      logger: mock,
      user_lookup: user_lookup
    ).call
  end
end
