# frozen_string_literal: true

module Adapters
  module Shared
    module SessionPrincipalMapper
      module_function

      # @param user [User]
      # @return [Domain::Shared::Dtos::SessionPrincipal]
      def from_user(user)
        Domain::Shared::Dtos::SessionPrincipal.new(
          id: user.id,
          email: user.email,
          name: user.name,
          admin: user.admin?,
          anonymous: user.anonymous?
        )
      end
    end
  end
end
