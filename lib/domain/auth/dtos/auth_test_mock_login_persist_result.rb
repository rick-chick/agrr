# frozen_string_literal: true

module Domain
  module Auth
    module Dtos
      AuthTestMockLoginPersistResult = Struct.new(
        :status,
        :user_name,
        :session_id,
        :expires_at,
        :error_messages,
        keyword_init: true
      )
    end
  end
end
