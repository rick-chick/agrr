# frozen_string_literal: true

require "test_helper"

class CropAiCreateApiPresenterTest < ActiveSupport::TestCase
  test "on_success renders created response with crop fields" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::Crop::Presenters::CropAiCreateApiPresenter.new(view: view_mock)
    output = Domain::Crop::Dtos::CropAiCreateOutput.new(
      http_status: :created,
      crop_id: 1,
      crop_name: "トマト",
      variety: "桃太郎",
      area_per_unit: 1.0,
      revenue_per_area: 2.0,
      stages_count: 0,
      message: "created"
    )

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :created, status
      assert json[:success]
      assert_equal 1, json[:crop_id]
      assert_equal "トマト", json[:crop_name]
    end

    presenter.on_success(output)

    view_mock.verify
  end

  test "on_failure renders error json" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::Crop::Presenters::CropAiCreateApiPresenter.new(view: view_mock)
    failure = Domain::Crop::Dtos::CropAiCreateFailure.new(http_status: :unauthorized, message: "login")

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :unauthorized, status
      assert_equal({ error: "login" }, json)
    end

    presenter.on_failure(failure)

    view_mock.verify
  end
end
