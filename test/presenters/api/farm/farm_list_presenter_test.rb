# frozen_string_literal: true

require 'test_helper'

class FarmListPresenterTest < ActiveSupport::TestCase
  test 'on_success sets @farm_list_data on view' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    farms = [mock('farm1'), mock('farm2')]

    view_mock.expects(:instance_variable_set).with('@farm_list_data', farms)

    presenter.on_success(farms)
  end

  test 'on_success handles empty farms array' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    farms = []

    view_mock.expects(:instance_variable_set).with('@farm_list_data', farms)

    presenter.on_success(farms)
  end

  test 'on_failure sets @farm_list_error on view' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Database connection failed')

    view_mock.expects(:instance_variable_set).with('@farm_list_error', error_dto)

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    failure_dto = 'Some error string'

    view_mock.expects(:instance_variable_set).with('@farm_list_error', failure_dto)

    presenter.on_failure(failure_dto)
  end
end