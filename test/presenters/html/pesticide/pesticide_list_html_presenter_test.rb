# frozen_string_literal: true

require "test_helper"

class PesticideListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @pesticides" do
    view_mock = mock
    pesticide_entity1 = mock
    pesticide_entity2 = mock
    pesticide_model1 = mock
    pesticide_model2 = mock

    pesticide_records_for_entities = lambda { |entities|
      assert_equal [ pesticide_entity1, pesticide_entity2 ], entities
      [ pesticide_model1, pesticide_model2 ]
    }

    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(
      view: view_mock,
      pesticide_records_for_entities: pesticide_records_for_entities
    )

    view_mock.expects(:instance_variable_set).with(:@pesticides, [ pesticide_model1, pesticide_model2 ])

    presenter.on_success([ pesticide_entity1, pesticide_entity2 ])
  end

  test "on_failure sets flash alert and empty @pesticides" do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(
      view: view_mock,
      pesticide_records_for_entities: ->(_) { [] }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@pesticides, [])

    presenter.on_failure(error_dto)
  end
end
