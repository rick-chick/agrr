require 'test_helper'

class ContactMessageDeliveryJobTest < ActiveJob::TestCase
  setup do
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
    ENV['CONTACT_DESTINATION_EMAIL'] = 'admin@example.com'
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
  end

  test 'enqueues and performs delivery job, updates status on success' do
    cm = ContactMessage.create!(
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Hi',
      message: 'Hello',
      status: 'queued'
    )

    perform_enqueued_jobs do
      ContactMessageDeliveryJob.perform_later(cm.id, ENV['CONTACT_DESTINATION_EMAIL'])
    end

    cm.reload
    assert_equal 'sent', cm.status
    assert_not_nil cm.sent_at
  end

  test 'marks as failed when mailer raises and retries' do
    cm = ContactMessage.create!(
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Hi',
      message: 'Hello',
      status: 'queued'
    )

    # stub mailer to raise
    ContactMessageMailer.any_instance.stubs(:notify_admin).raises(StandardError.new('SMTP error'))
    assert_raises(StandardError) do
      ContactMessageDeliveryJob.new.perform(cm.id, ENV['CONTACT_DESTINATION_EMAIL'])
    end

    cm.reload
    assert_equal 'failed', cm.status
  end
end

