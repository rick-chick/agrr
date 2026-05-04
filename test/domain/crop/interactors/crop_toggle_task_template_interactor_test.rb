# frozen_string_literal: true

require "test_helper"

class CropToggleTaskTemplateInteractorTest < ActiveSupport::TestCase
  test "on_success delegates to toggle service" do
    user = Domain::Shared::Dtos::UserDto.new(id: 1, admin: true)
    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    crop = mock
    crop_gateway = mock
    crop_gateway.expects(:find_authorized_model_for_edit).with(user, 9).returns(crop)

    agricultural_task = mock
    task_gateway = mock
    task_gateway.expects(:find_model).with(44).returns(agricultural_task)

    result = CropToggleTaskTemplateService::Result.new(
      available_agricultural_tasks: [],
      selected_task_ids: [],
      task_schedule_blueprints: []
    )

    toggle_service = mock
    toggle_service.expects(:call).with(crop: crop, agricultural_task: agricultural_task).returns(result)

    output = mock
    output.expects(:on_success).with(result)

    Domain::Crop::Interactors::CropToggleTaskTemplateInteractor.new(
      output_port: output,
      user_id: 1,
      crop_id: 9,
      agricultural_task_id: 44,
      gateway: crop_gateway,
      agricultural_task_gateway: task_gateway,
      toggle_service: toggle_service,
      translator: mock,
      logger: mock,
      user_lookup: user_lookup
    ).call
  end
end
