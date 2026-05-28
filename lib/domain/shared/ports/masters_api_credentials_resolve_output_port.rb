# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      module MastersApiCredentialsResolveOutputPort
        # @param principal [Domain::Shared::Dtos::SessionPrincipal]
        def on_success(principal:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_invalid_api_key
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def on_login_required
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
