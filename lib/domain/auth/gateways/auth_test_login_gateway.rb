# frozen_string_literal: true

module Domain
  module Auth
    module Gateways
      module AuthTestLoginGateway
        # @param input_dto [Domain::Auth::Dtos::AuthTestMockLoginInputDto]
        # @return [Domain::Auth::Dtos::AuthTestMockLoginPersistResult]
        def persist_mock_user_and_session!(input_dto)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
