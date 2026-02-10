# frozen_string_literal: true
require 'test_helper'
require_relative '../../../../lib/domain/contact_messages/dtos/create_contact_message_input'

module Adapters
  module ContactMessages
    module Gateways
      class ContactMessageActiveRecordGatewayTest < ActiveSupport::TestCase
        DESTINATION_EMAIL = 'admin@example.com'.freeze

        def build_gateway(delivery_job: nil)
          ContactMessageActiveRecordGateway.new(
            destination_email: DESTINATION_EMAIL,
            delivery_job: delivery_job || Minitest::Mock.new
          )
        end

        test 'find_by_id returns entity when exists and nil when not' do
          gateway = build_gateway

          record = ::ContactMessage.create!(
            name: 'Taro',
            email: 'taro@example.com',
            subject: 'Hi',
            message: 'hello',
            status: 'queued',
            source: 'static-cta'
          )

          entity = gateway.find_by_id(record.id)
          assert_not_nil entity
          assert_equal record.id, entity.id
          assert_equal record.email, entity.email
          assert_equal 'static-cta', entity.source

          assert_nil gateway.find_by_id(0)
        end

        test 'create persists queued entity and enqueues delivery job' do
          delivery_job = Minitest::Mock.new
          delivery_job.expect(:perform_later, nil) do |record_id, destination_email|
            assert record_id.is_a?(Integer)
            assert_equal DESTINATION_EMAIL, destination_email
          end

          gateway = build_gateway(delivery_job: delivery_job)
          create_dto = ::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: 'Hanako',
            email: 'hana@example.com',
            subject: 'Test',
            message: 'hello',
            source: 'landing-page'
          )

          entity = gateway.create(create_dto)

          assert_not_nil entity
          assert_equal 'hana@example.com', entity.email
          assert_equal 'queued', entity.status
          assert_equal 'landing-page', entity.source

          persisted = ::ContactMessage.find_by(email: 'hana@example.com')
          assert_not_nil persisted
          assert_equal 'queued', persisted.status
          assert_equal 'landing-page', persisted.source

          delivery_job.verify
        end

        test 'create raises on validation failure without enqueueing job' do
          delivery_job = Minitest::Mock.new
          gateway = build_gateway(delivery_job: delivery_job)

          create_dto = ::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: 'NoEmail',
            email: 'invalid',
            subject: 'x',
            message: ''
          )

          assert_raises(ActiveRecord::RecordInvalid) { gateway.create(create_dto) }
          delivery_job.verify
        end
      end
    end
  end
end

