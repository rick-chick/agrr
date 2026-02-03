# frozen_string_literal: true

require 'test_helper'

class CultivationPlanDeletePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and DeletionUndoResponse json' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    # Mock DeletionUndoEvent
    event = mock
    event.stubs(:undo_token).returns('test-undo-token-123')
    event.stubs(:metadata).returns({
      'undo_deadline' => '2026-02-03T12:00:00Z',
      'resource_label' => 'Test Plan',
      'resource_dom_id' => 'cultivation_plan_8'
    })
    event.stubs(:toast_message).returns('プラン Test Plan を削除しました')
    event.stubs(:auto_hide_after).returns(60000)
    event.stubs(:resource_type).returns('CultivationPlan')
    event.stubs(:resource_id).returns('8')

    # Mock DTO
    destroy_output_dto = Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto.new(undo: event)

    # Mock view methods
    view_mock.expects(:undo_deletion_path).with(undo_token: 'test-undo-token-123').returns('/undo_deletion?undo_token=test-undo-token-123')

    expected_json = {
      undo_token: 'test-undo-token-123',
      undo_deadline: '2026-02-03T12:00:00Z',
      toast_message: 'プラン Test Plan を削除しました',
      undo_path: '/undo_deletion?undo_token=test-undo-token-123',
      auto_hide_after: 60000,
      resource: 'Test Plan',
      redirect_path: '/plans',
      resource_dom_id: 'cultivation_plan_8'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(destroy_output_dto)
  end

  test 'on_success generates resource_dom_id when not in metadata' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    # Mock DeletionUndoEvent without resource_dom_id in metadata
    event = mock
    event.stubs(:undo_token).returns('test-undo-token-456')
    event.stubs(:metadata).returns({
      'undo_deadline' => '2026-02-03T12:00:00Z',
      'resource_label' => 'Another Plan'
    })
    event.stubs(:toast_message).returns('プラン Another Plan を削除しました')
    event.stubs(:auto_hide_after).returns(5)
    event.stubs(:resource_type).returns('CultivationPlan')
    event.stubs(:resource_id).returns('42')

    destroy_output_dto = Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto.new(undo: event)

    view_mock.expects(:undo_deletion_path).with(undo_token: 'test-undo-token-456').returns('/undo_deletion?undo_token=test-undo-token-456')

    expected_json = {
      undo_token: 'test-undo-token-456',
      undo_deadline: '2026-02-03T12:00:00Z',
      toast_message: 'プラン Another Plan を削除しました',
      undo_path: '/undo_deletion?undo_token=test-undo-token-456',
      auto_hide_after: 5,
      resource: 'Another Plan',
      redirect_path: '/plans',
      resource_dom_id: 'cultivation_plan_42'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(destroy_output_dto)
  end

  test 'on_failure calls view.render_response with not_found status when plan not found' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new(I18n.t('plans.errors.not_found'))

    expected_json = {
      error: I18n.t('plans.errors.not_found')
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :not_found
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status when deletion fails' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    error_message = I18n.t('plans.errors.delete_failed')
    error_dto = Domain::Shared::Dtos::ErrorDto.new(error_message)

    expected_json = {
      error: error_message
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status when deletion error occurs' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    error_message = I18n.t('plans.errors.delete_error', message: 'Undo token generation failed')
    error_dto = Domain::Shared::Dtos::ErrorDto.new(error_message)

    expected_json = {
      error: error_message
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status for generic errors' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Some other error occurred')

    expected_json = {
      error: 'Some other error occurred'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: view_mock)

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
