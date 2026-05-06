# frozen_string_literal: true

module Domain
  module ContactMessages
    module Dtos
      class CreateContactMessageInput
        attr_reader :name, :email, :subject, :message, :source, :recaptcha_token, :remote_ip

        def initialize(name:, email:, subject:, message:, source: nil, recaptcha_token: nil, remote_ip: nil)
          @name = name
          @email = email
          @subject = subject
          @message = message
          @source = source
          @recaptcha_token = recaptcha_token
          @remote_ip = remote_ip
        end
      end
    end
  end
end
