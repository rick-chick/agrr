require 'test_helper'

class ContactMessageMailerTest < ActionMailer::TestCase
  test 'notify_admin builds email' do
    cm = ContactMessage.create!(
      name: 'Taro',
      email: 'taro@example.com',
      subject: 'Inquiry',
      message: 'Hello',
      status: 'queued'
    )

    mail = ContactMessageMailer.with(contact_message: cm, destination: 'admin@example.com').notify_admin

    assert_equal ['admin@example.com'], mail.to
    assert_includes mail.subject, 'Inquiry'
    assert_equal ['taro@example.com'], mail.reply_to
  end
end

