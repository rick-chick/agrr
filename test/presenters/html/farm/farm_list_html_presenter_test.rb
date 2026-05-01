# frozen_string_literal: true

require "test_helper"

class FarmListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @farms and @reference_farms using injected procs" do
    view_mock = mock
    farm_entity1 = mock
    farm_entity2 = mock
    farm_model1 = mock
    farm_model2 = mock
    ref_list = [ Object.new ]

    farm_records_for_entities = lambda { |entities|
      assert_equal [ farm_entity1, farm_entity2 ], entities
      [ farm_model1, farm_model2 ]
    }
    reference_farms = -> { ref_list }

    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(
      view: view_mock,
      farm_records_for_entities: farm_records_for_entities,
      reference_farms: reference_farms
    )

    view_mock.expects(:instance_variable_set).with(:@farms, [ farm_model1, farm_model2 ])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, ref_list)

    presenter.on_success([ farm_entity1, farm_entity2 ])
  end

  test "on_success sets @reference_farms from proc when empty for non-admin pattern" do
    view_mock = mock
    farm_entity = mock
    farm_model = mock

    farm_records_for_entities = ->(_entities) { [ farm_model ] }
    reference_farms = -> { [] }

    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(
      view: view_mock,
      farm_records_for_entities: farm_records_for_entities,
      reference_farms: reference_farms
    )

    view_mock.expects(:instance_variable_set).with(:@farms, [ farm_model ])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [])

    presenter.on_success([ farm_entity ])
  end

  test "on_failure sets flash alert and empty arrays" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(
      view: view_mock,
      farm_records_for_entities: ->(_) { [] },
      reference_farms: -> { [] }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@farms, [])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [])

    presenter.on_failure(error_dto)
  end
end
