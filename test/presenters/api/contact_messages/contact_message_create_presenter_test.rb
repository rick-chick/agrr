# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class ContactMessageCreatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with created status and serialized json' do
    view_mock = mock
    presenter = Api::ContactMessages::ContactMessageCreatePresenter.new(view: view_mock)

    cm = OpenStruct.new(
      id: 123,
      status: 'sent',
      created_at: Time.utc(2026, 2, 10, 12, 34, 56),
      sent_at: Time.utc(2026, 2, 10, 12, 35, 0)
    )

    success_dto = OpenStruct.new(contact_message: cm)

    expected_json = {
      id: 123,
      status: 'sent',
      created_at: '2026-02-10T12:34:56Z',
      sent_at: '2026-02-10T12:35:00Z'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :created
    )

    presenter.on_success(success_dto)
  end

  test 'on_success includes null sent_at when not persisted yet' do
    view_mock = mock
    presenter = Api::ContactMessages::ContactMessageCreatePresenter.new(view: view_mock)

    cm = OpenStruct.new(
      id: 124,
      status: 'queued',
      created_at: Time.utc(2026, 2, 10, 12, 34, 56),
      sent_at: nil
    )

    success_dto = OpenStruct.new(contact_message: cm)

    expected_json = {
      id: 124,
      status: 'queued',
      created_at: '2026-02-10T12:34:56Z',
      sent_at: nil
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :created
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure renders validation errors with unprocessable_entity' do
    view_mock = mock
    presenter = Api::ContactMessages::ContactMessageCreatePresenter.new(view: view_mock)

    errors_obj = OpenStruct.new(messages: { email: ['is invalid'], message: ["can't be blank"] })
    failure_dto = OpenStruct.new(errors: errors_obj)

    expected_json = {
      error: 'Validation failed',
      field_errors: { email: ['is invalid'], message: ["can't be blank"] }
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(failure_dto)
  end

  test 'on_failure renders generic error with internal_server_error' do
    view_mock = mock
    presenter = Api::ContactMessages::ContactMessageCreatePresenter.new(view: view_mock)

    failure = 'Something went wrong'

    view_mock.expects(:render_response).with(
      json: { error: Api::ContactMessages::ContactMessageCreatePresenter::INTERNAL_SERVER_ERROR_MESSAGE },
      status: :internal_server_error
    )

    presenter.on_failure(failure)
  end
end

