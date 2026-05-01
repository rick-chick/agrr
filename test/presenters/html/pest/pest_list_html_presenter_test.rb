# frozen_string_literal: true

require "test_helper"

class PestListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @pests" do
    view_mock = mock
    pest_models_from_entities = lambda do |entities|
      assert_equal [ 1, 2 ], entities.map(&:id)
      [ :m1, :m2 ]
    end
    presenter = Presenters::Html::Pest::PestListHtmlPresenter.new(
      view: view_mock,
      pest_models_from_entities: pest_models_from_entities
    )

    pest_entity1 = mock
    pest_entity2 = mock
    pest_entity1.expects(:id).returns(1).at_least_once
    pest_entity2.expects(:id).returns(2).at_least_once

    view_mock.expects(:instance_variable_set).with(:@pests, [ :m1, :m2 ])

    pests = [ pest_entity1, pest_entity2 ]
    presenter.on_success(pests)
  end

  test "on_failure sets flash alert and empty array" do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestListHtmlPresenter.new(
      view: view_mock,
      pest_models_from_entities: ->(_) { [] }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@pests, [])

    presenter.on_failure(error_dto)
  end
end
