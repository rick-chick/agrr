# frozen_string_literal: true

module Domain
  module Auth
    module Ports
      module AuthUserLogoutOutputPort
        def on_success
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_not_logged_in
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
