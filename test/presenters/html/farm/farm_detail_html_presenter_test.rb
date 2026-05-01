# frozen_string_literal: true

require "test_helper"

class FarmDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @farm and @fields" do
    view_mock = mock
    farm_model = mock
    field_model1 = mock
    field_model2 = mock
    farm_detail_dto = mock

    farm_detail_view_for = lambda { |dto|
      assert_equal farm_detail_dto, dto
      { farm: farm_model, fields: [ field_model1, field_model2 ] }
    }

    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(
      view: view_mock,
      farm_detail_view_for: farm_detail_view_for
    )

    view_mock.expects(:instance_variable_set).with(:@farm, farm_model)
    view_mock.expects(:instance_variable_set).with(:@fields, [ field_model1, field_model2 ])

    presenter.on_success(farm_detail_dto)
  end

  test "on_failure sets flash alert and redirects" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(
      view: view_mock,
      farm_detail_view_for: ->(_) { {} }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:farms_path).returns("/farms")
    view_mock.expects(:redirect_to).with("/farms")

    presenter.on_failure(error_dto)
  end
end
