class ContactMessageDeliveryJob < ActiveJob::Base
  queue_as :default

  # retry up to 3 times with exponential backoff
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(contact_message_id, destination_email)
    cm = ContactMessage.find_by(id: contact_message_id)
    return unless cm

    begin
      ContactMessageMailer.with(contact_message: cm, destination: destination_email).notify_admin.deliver_now
      cm.update!(status: 'sent', sent_at: Time.current)
    rescue => e
      Rails.logger.error("[ContactMessageDeliveryJob] delivery failed: #{e.class} #{e.message}")
      cm.update!(status: 'failed') if cm.persisted?
      # re-raise to trigger retry_on
      raise
    end
  end
end

