# frozen_string_literal: true

require "test_helper"

class CropMastersTaskTemplateCreatePresenterTest < ActiveSupport::TestCase
  test "on_success renders created template response" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropMastersTaskTemplateCreatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    time = Time.zone.parse("2025-01-01 12:00:00")
    task = Domain::Crop::Dtos::AgriculturalTaskSnapshot.new(
      id: 10,
      name: "土壌準備",
      description: "耕す作業",
      is_reference: true
    )
    template = Domain::Crop::Dtos::MastersCropTaskTemplate.new(
      id: 1,
      crop_id: 2,
      agricultural_task_id: 10,
      name: "土づくり",
      description: "準備",
      time_per_sqm: 0.5,
      weather_dependency: "low",
      required_tools: [ "鍬" ],
      skill_level: "beginner",
      agricultural_task: task,
      created_at: time,
      updated_at: time
    )

    expected_json = {
      id: 1,
      crop_id: 2,
      agricultural_task_id: 10,
      name: "土づくり",
      description: "準備",
      time_per_sqm: 0.5,
      weather_dependency: "low",
      required_tools: [ "鍬" ],
      skill_level: "beginner",
      agricultural_task: {
        id: 10,
        name: "土壌準備",
        description: "耕す作業",
        is_reference: true
      },
      created_at: time,
      updated_at: time
    }

    view_mock.expects(:render_response).with(json: expected_json, status: :created)

    presenter.on_success(template)
  end

  test "on_failure renders missing agricultural_task_id error" do
    assert_failure_response(
      reason: :missing_agricultural_task_id,
      expected_json: { error: "agricultural_task_id is required" },
      status: :unprocessable_entity
    )
  end

  test "on_failure renders agricultural task not found error" do
    assert_failure_response(
      reason: :agricultural_task_not_found,
      expected_json: { error: "AgriculturalTask not found" },
      status: :not_found
    )
  end

  test "on_failure renders forbidden error" do
    assert_failure_response(
      reason: :forbidden,
      expected_json: { error: "You do not have permission to associate this agricultural task" },
      status: :forbidden
    )
  end

  test "on_failure renders duplicate error" do
    assert_failure_response(
      reason: :duplicate,
      expected_json: { error: "AgriculturalTask is already associated with this crop" },
      status: :unprocessable_entity
    )
  end

  test "on_failure renders validation errors" do
    assert_failure_response(
      reason: :validation_failed,
      errors: [ "Name can't be blank" ],
      expected_json: { errors: [ "Name can't be blank" ] },
      status: :unprocessable_entity
    )
  end

  test "on_failure renders crop not found error" do
    assert_failure_response(
      reason: :crop_not_found,
      expected_json: { error: "Crop not found" },
      status: :not_found
    )
  end

  test "on_failure with unknown reason uses message when present" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropMastersTaskTemplateCreatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
      reason: :totally_unknown,
      message: "Custom detail"
    )

    view_mock.expects(:render_response).with(
      json: { error: "Custom detail" },
      status: :unprocessable_entity
    )
    presenter.on_failure(failure_dto)
  end

  test "on_failure with unknown reason without message uses unexpected fallback" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropMastersTaskTemplateCreatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
      reason: :totally_unknown
    )

    view_mock.expects(:render_response).with(
      json: { error: "Request could not be processed" },
      status: :unprocessable_entity
    )
    presenter.on_failure(failure_dto)
  end

  private

  def translator_stub
    @translator_stub ||= Object.new.tap do |o|
      o.define_singleton_method(:t) { |_key, **kwargs| kwargs.fetch(:default) }
    end
  end

  def assert_failure_response(reason:, expected_json:, status:, errors: nil)
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropMastersTaskTemplateCreatePresenter.new(
      view: view_mock,
      translator: translator_stub
    )
    failure_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
      reason: reason,
      errors: errors
    )

    view_mock.expects(:render_response).with(json: expected_json, status: status)

    presenter.on_failure(failure_dto)
  end
end
