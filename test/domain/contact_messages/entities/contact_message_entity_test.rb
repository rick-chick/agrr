# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module ContactMessages
    module Entities
      class ContactMessageEntityTest < DomainLibTestCase
        test "initializes with provided attributes and status helpers" do
          now = Time.utc(2026, 1, 1)
          entity = Domain::ContactMessages::Entities::ContactMessage.new(
            id: 1,
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi there",
            status: "sent",
            created_at: now,
            sent_at: now
          )

          assert_equal 1, entity.id
          assert_equal "Taro", entity.name
          assert_equal "taro@example.com", entity.email
          assert entity.sent?
          refute entity.failed?
          refute entity.queued?
        end

        test "requires email and message to be present" do
          entity = Domain::ContactMessages::Entities::ContactMessage.new(email: "", message: "")

          refute entity.valid?
          assert !entity.errors[:email].nil? && !entity.errors[:email].empty?
          assert !entity.errors[:message].nil? && !entity.errors[:message].empty?
        end

        test "enforces length limits for optional fields" do
          entity = Domain::ContactMessages::Entities::ContactMessage.new(email: "a@b.com", message: "ok")
          entity.name = "n" * 300
          entity.subject = "s" * 300

          refute entity.valid?
          assert !entity.errors[:name].nil? && !entity.errors[:name].empty?
          assert !entity.errors[:subject].nil? && !entity.errors[:subject].empty?
        end
      end
    end
  end
end
