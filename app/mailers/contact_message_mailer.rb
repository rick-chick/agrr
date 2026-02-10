class ContactMessageMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'no-reply@example.com')

  def notify_admin
    cm = params.fetch(:contact_message)
    destination = params.fetch(:destination)
    mail(
      to: destination,
      subject: "[Contact] #{cm.subject.presence || 'New inquiry'}",
      reply_to: cm.email
    ) do |format|
      format.text { render plain: render_message_text(cm) }
      format.html { render html: render_message_html(cm).html_safe }
    end
  end

  private

  def render_message_text(cm)
    <<~TEXT
    Name: #{cm.name}
    Email: #{cm.email}
    Subject: #{cm.subject}
    Message:
    #{cm.message}
    TEXT
  end

  def render_message_html(cm)
    <<~HTML
    <p><strong>Name:</strong> #{ERB::Util.html_escape(cm.name)}</p>
    <p><strong>Email:</strong> #{ERB::Util.html_escape(cm.email)}</p>
    <p><strong>Subject:</strong> #{ERB::Util.html_escape(cm.subject)}</p>
    <p><strong>Message:</strong></p>
    <div>#{ERB::Util.html_escape(cm.message).gsub("\n", '<br>')}</div>
    HTML
  end
end

