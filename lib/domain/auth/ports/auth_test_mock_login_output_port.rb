# frozen_string_literal: true

module Domain
  module Auth
    module Ports
      module AuthTestMockLoginOutputPort
        def on_environment_forbidden
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_missing_mock
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_create_failed(error_messages:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_success_process_saved_plan(session_id:, expires_at:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_success_return_to(url:, session_id:, expires_at:, user_name:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_success_root(session_id:, expires_at:, user_name:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
