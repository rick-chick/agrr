# frozen_string_literal: true

require "test_helper"

class FarmListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test "on_success sets @farms and @reference_farms for admin user" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: view_mock, is_admin: true)

    farm_entity1 = mock
    farm_entity2 = mock
    farm_model1 = mock
    farm_model2 = mock
    farm_entity1.expects(:id).returns(1)
    farm_entity2.expects(:id).returns(2)
    gw = mock
    gw.expects(:find_model).with(1).returns(farm_model1)
    gw.expects(:find_model).with(2).returns(farm_model2)
    Domain::Farm::Gateways::FarmGateway.stubs(:default).returns(gw)

    reference_farm = mock
    Farm.expects(:reference).returns([ reference_farm ])

    view_mock.expects(:instance_variable_set).with(:@farms, [ farm_model1, farm_model2 ])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [ reference_farm ])

    farms = [ farm_entity1, farm_entity2 ]
    presenter.on_success(farms)
  end

  test "on_success sets @farms and empty @reference_farms for regular user" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: view_mock, is_admin: false)

    farm_entity = mock
    farm_model = mock
    farm_entity.expects(:id).returns(9)
    gw = mock
    gw.expects(:find_model).with(9).returns(farm_model)
    Domain::Farm::Gateways::FarmGateway.stubs(:default).returns(gw)

    view_mock.expects(:instance_variable_set).with(:@farms, [ farm_model ])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [])

    farms = [ farm_entity ]
    presenter.on_success(farms)
  end

  test "on_failure sets flash alert and empty arrays" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: view_mock, is_admin: false)

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
