require 'test_helper'

class Api::V1::ContactMessagesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @url = '/api/v1/contact_messages'
    ENV['CONTACT_DESTINATION_EMAIL'] = 'admin@example.com'
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter = :test
  end

  def contact_message_payload(overrides = {})
    {
      contact_message: {
        name: 'Taro',
        email: 'taro@example.com',
        subject: 'Hello',
        message: 'This is a message'
      }.merge(overrides)
    }
  end

  test 'creates contact message and enqueues job (success path)' do
    post @url, params: contact_message_payload, as: :json

    assert_response :created
    body = JSON.parse(@response.body)
    assert_equal 'queued', body['status']
    assert body['id'].is_a?(Integer)

    # job should be enqueued
    assert_enqueued_jobs 1
  end

  test 'returns 422 for invalid input' do
    post @url, params: contact_message_payload(email: 'invalid-email', message: ''), as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_equal 'Validation failed', body['error']
    assert body['field_errors'].present?
  end

  test 'returns 503 if destination email is not configured' do
    ENV['CONTACT_DESTINATION_EMAIL'] = ''

    post @url, params: contact_message_payload, as: :json

    assert_response :service_unavailable
    body = JSON.parse(@response.body)
    assert_includes body['error'], 'CONTACT_DESTINATION_EMAIL'
    assert_enqueued_jobs 0
  end
end

