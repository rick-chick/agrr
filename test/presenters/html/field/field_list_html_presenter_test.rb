# frozen_string_literal: true

require "test_helper"

class FieldListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @fields" do
    view_mock = mock
    farm = mock
    field_entity1 = mock
    field_entity2 = mock
    field_model1 = mock
    field_model2 = mock

    field_records_for_entities = lambda { |entities|
      assert_equal [ field_entity1, field_entity2 ], entities
      [ field_model1, field_model2 ]
    }

    presenter = Presenters::Html::Field::FieldListHtmlPresenter.new(
      view: view_mock,
      farm: farm,
      field_records_for_entities: field_records_for_entities
    )

    view_mock.expects(:instance_variable_set).with(:@fields, [ field_model1, field_model2 ])
    view_mock.expects(:instance_variable_set).with(:@farm, farm)

    presenter.on_success([ field_entity1, field_entity2 ])
  end

  test "on_failure sets flash alert and empty array" do
    view_mock = mock
    farm = mock
    presenter = Presenters::Html::Field::FieldListHtmlPresenter.new(
      view: view_mock,
      farm: farm,
      field_records_for_entities: ->(_) { [] }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@fields, [])
    view_mock.expects(:instance_variable_set).with(:@farm, farm)

    presenter.on_failure(error_dto)
  end
end
