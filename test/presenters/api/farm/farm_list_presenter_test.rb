# frozen_string_literal: true

require 'test_helper'

class FarmListPresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and serialized farm data' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    # テスト用の Farm エンティティを作成
    farm1 = mock
    farm1.expects(:id).returns(1)
    farm1.expects(:name).returns('Test Farm 1')
    farm1.expects(:latitude).returns(35.6895)
    farm1.expects(:longitude).returns(139.6917)
    farm1.expects(:region).returns('jp')
    farm1.expects(:user_id).returns(123)
    farm1.expects(:created_at).returns(Time.parse('2024-01-01T00:00:00.000Z'))
    farm1.expects(:updated_at).returns(Time.parse('2024-01-01T00:00:00.000Z'))
    farm1.expects(:is_reference).returns(false)

    farm2 = mock
    farm2.expects(:id).returns(2)
    farm2.expects(:name).returns('Reference Farm')
    farm2.expects(:latitude).returns(43.0642)
    farm2.expects(:longitude).returns(141.3468)
    farm2.expects(:region).returns('jp')
    farm2.expects(:user_id).returns(nil)
    farm2.expects(:created_at).returns(Time.parse('2024-01-01T00:00:00.000Z'))
    farm2.expects(:updated_at).returns(Time.parse('2024-01-01T00:00:00.000Z'))
    farm2.expects(:is_reference).returns(true)

    farms = [farm1, farm2]

    expected_json = [
      {
        id: 1,
        name: 'Test Farm 1',
        latitude: 35.6895,
        longitude: 139.6917,
        region: 'jp',
        user_id: 123,
        created_at: '2024-01-01T00:00:00.000Z',
        updated_at: '2024-01-01T00:00:00.000Z',
        is_reference: false
      },
      {
        id: 2,
        name: 'Reference Farm',
        latitude: 43.0642,
        longitude: 141.3468,
        region: 'jp',
        user_id: nil,
        created_at: '2024-01-01T00:00:00.000Z',
        updated_at: '2024-01-01T00:00:00.000Z',
        is_reference: true
      }
    ]

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(farms)
  end

  test 'on_success handles empty farms array' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    farms = []

    expected_json = []

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(farms)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Database connection failed')

    expected_json = {
      error: 'Database connection failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    failure_dto = 'Some error string'

    expected_json = {
      error: 'Some error string'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(failure_dto)
  end
end