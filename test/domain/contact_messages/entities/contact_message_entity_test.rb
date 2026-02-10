# frozen_string_literal: true

require 'test_helper'

module ContactMessages
  module Entities
    class ContactMessageEntityTest < ActiveSupport::TestCase
      test 'initializes with provided attributes and status helpers' do
        now = Time.current
        entity = ContactMessages::Entities::ContactMessage.new(
          id: 1,
          name: 'Taro',
          email: 'taro@example.com',
          subject: 'Hello',
          message: 'Hi there',
          status: 'sent',
          created_at: now,
          sent_at: now
        )

        assert_equal 1, entity.id
        assert_equal 'Taro', entity.name
        assert_equal 'taro@example.com', entity.email
        assert entity.sent?
        refute entity.failed?
        refute entity.queued?
      end

      test 'requires email and message to be present' do
        entity = ContactMessages::Entities::ContactMessage.new(email: '', message: '')

        refute entity.valid?
        assert entity.errors[:email].present?
        assert entity.errors[:message].present?
      end

      test 'enforces length limits for optional fields' do
        entity = ContactMessages::Entities::ContactMessage.new(email: 'a@b.com', message: 'ok')
        entity.name = 'n' * 300
        entity.subject = 's' * 300

        refute entity.valid?
        assert entity.errors[:name].present?
        assert entity.errors[:subject].present?
      end
    end
  end
end
