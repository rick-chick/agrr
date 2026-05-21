# frozen_string_literal: true

require "test_helper"

class CropCreateApiPresenterTest < ActiveSupport::TestCase
  test "on_failure renders forbidden when message is reference_only_admin" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::Crop::Presenters::CropCreateApiPresenter.new(view: view_mock)
    msg = I18n.t("crops.flash.reference_only_admin")
    error_dto = Domain::Shared::Dtos::Error.new(msg)

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter.on_failure(error_dto)

    view_mock.verify
  end

  test "on_failure renders unprocessable_entity with errors array for other messages" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::Crop::Presenters::CropCreateApiPresenter.new(view: view_mock)
    error_dto = Domain::Shared::Dtos::Error.new("other")

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :unprocessable_entity, status
      assert_equal({ errors: [ "other" ] }, json)
    end

    presenter.on_failure(error_dto)

    view_mock.verify
  end
end
