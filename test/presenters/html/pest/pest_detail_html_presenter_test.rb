# frozen_string_literal: true

require "test_helper"

class PestDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @pest and @crops" do
    view_mock = mock
    crop1 = mock
    crop2 = mock
    pest_detail_dto = mock
    pest_detail_dto.expects(:associated_crops).returns([ crop1, crop2 ])

    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@pest, pest_detail_dto)
    view_mock.expects(:instance_variable_set).with(:@crops, [ crop1, crop2 ])

    presenter.on_success(pest_detail_dto)
  end

  test "on_failure redirects with alert" do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    view_mock.expects(:pests_path).returns("/pests")
    view_mock.expects(:redirect_to).with("/pests", alert: "Test error")

    presenter.on_failure(error_dto)
  end
end
